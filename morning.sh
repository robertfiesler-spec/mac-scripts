#!/bin/zsh
# ============================================
# morning.sh
# Daily morning briefing for Rob Fiesler
# BiXBiT USA
# ============================================

# Keep Mac awake for duration of this script
caffeinate -i -w $$ &

# --- Header ---
echo "========================================"
echo "  GOOD MORNING, ROB"
echo "  $(date '+%A, %B %d %Y')"
echo "========================================"

# --- Bitcoin Price ---
echo ""
echo "💰 BITCOIN"
BTC_JSON=$(curl -s "https://api.coinbase.com/v2/prices/BTC-USD/spot")
BTC_PRICE=$(echo "$BTC_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('\$' + '{:,}'.format(int(float(d['data']['amount']))))")
echo "  Price:  $BTC_PRICE"

# --- System ---
echo ""
echo "⚙️  SYSTEM"

vm_stat | awk '
  /Pages active/   { active=$3 }
  /Pages inactive/ { inactive=$3 }
  END {
    used=(active+inactive)*4096/1073741824
    printf "  Memory: %.2f GB used\n", used
  }'

df -h / | awk 'NR==2 {print "  Disk:   " $3 " / " $2 " (" $5 " full)"}'
uptime | awk -F'up ' '{split($2,a,","); gsub(/^ +| +$/,"",a[1]); print "  Uptime: " a[1]}'

# --- Network ---
echo ""
echo "🌐 NETWORK"
if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
  echo "  Internet: Connected"
else
  echo "  Internet: No connection"
fi

# --- Miners ---
echo ""
echo "🔍 MINERS"

scan_subnet() {
  local SUBNET=$1
  local COUNT=0
  local PIDS=()
  local TMPDIR=$(mktemp -d)

  for i in {1..254}; do
    IP="$SUBNET.$i"
    (ping -c 1 -W 1 "$IP" &>/dev/null && echo "alive" > "$TMPDIR/$i") &
    PIDS+=($!)
  done

  for PID in $PIDS; do
    wait $PID
  done

  COUNT=$(ls "$TMPDIR" 2>/dev/null | wc -l | tr -d ' ')
  rm -rf "$TMPDIR"
  echo "  $SUBNET  →  $COUNT devices alive"
}

scan_subnet "192.168.188"
scan_subnet "192.168.189"

# --- Mining Guardian ---
echo ""
echo "🛡️  MINING GUARDIAN"
DB="/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"

if [ -f "$DB" ]; then
  python3 - <<'PYEOF'
import sqlite3, os

db = "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"
conn = sqlite3.connect(db)

# Get latest scan summary
row = conn.execute("""
    SELECT scanned_at, total_miners, online, offline, issues
    FROM scans ORDER BY id DESC LIMIT 1
""").fetchone()

if row:
    scanned_at, total, online, offline, issues = row
    # Trim to readable time
    t = scanned_at[:16].replace("T", " ")
    print(f"  Last scan:  {t}")
    print(f"  Fleet:      {total} miners  |  {online} online  |  {offline} offline")
    if issues == 0:
        print(f"  Status:     ✅ All miners healthy")
    else:
        # Break down by action type
        rows = conn.execute("""
            SELECT action, COUNT(*) FROM miner_readings
            WHERE scan_id = (SELECT MAX(id) FROM scans)
            AND action IS NOT NULL
            GROUP BY action
        """).fetchall()
        action_map = dict(rows)
        parts = []
        if action_map.get("PDU_CYCLE"):
            parts.append(f"{action_map['PDU_CYCLE']} PDU cycle")
        if action_map.get("RESTART"):
            parts.append(f"{action_map['RESTART']} firmware restart")
        if action_map.get("TEMP_ACTION_REQUIRED"):
            parts.append(f"{action_map['TEMP_ACTION_REQUIRED']} high temp")
        if action_map.get("MONITOR"):
            parts.append(f"{action_map['MONITOR']} monitor")
        print(f"  Status:     ⚠️  {issues} issues — {', '.join(parts)}")
else:
    print("  No scan data yet.")

conn.close()
PYEOF
else
  echo "  No database found — run Mining Guardian first."
fi

# --- Warehouse Mechanical (HVAC) ---
echo ""
echo "🏭 WAREHOUSE MECHANICAL"
python3 - <<'PYEOF'
import subprocess, json

AUTH = "BigStar:BigSt@r2020"
BASE = "https://192.168.188.235/api/rest/v1/protocols/bacnet/local/objects"

def get(url):
    r = subprocess.run(
        ["curl", "-sk", url, "-u", AUTH, "-L", "--max-time", "6"],
        capture_output=True, text=True, timeout=8
    )
    try:
        return json.loads(r.stdout)
    except:
        return None

def prop(t, oid, p):
    d = get(f"{BASE}/{t}/{oid}/properties/{p}")
    return d.get("value") if d and "value" in d else None

def f(v, dec=1):
    try:
        return f"{float(v):.{dec}f}" if v and str(v) != "NaN" else "N/A"
    except:
        return "N/A"

try:
    sup  = prop("analog-input",  "101", "present-value")
    ret  = prop("analog-input",  "102", "present-value")
    dp   = prop("analog-input",  "103", "present-value")
    pump = prop("binary-input",  "208", "present-value")
    basin= prop("binary-input",  "302", "present-value")
    leak = prop("binary-value",  "22",  "present-value")
    cwp1 = prop("analog-output", "101", "present-value")
    cwp2 = prop("analog-output", "102", "present-value")
    ct1  = prop("analog-output", "103", "present-value")
    ct2  = prop("analog-output", "104", "present-value")

    try:
        delta = f"{float(ret) - float(sup):.1f}" if sup and ret else "N/A"
    except:
        delta = "N/A"

    pump_str  = "🟢 ON" if str(pump).lower() == "active" else "🔴 OFF"
    basin_str = "🟢 OK" if str(basin).lower() == "active" else "🔴 LOW"
    leak_str  = "🔴 ALARM" if str(leak).lower() == "active" else "✅ OK"

    print(f"  Supply Water  :  {f(sup)}°F")
    print(f"  Return Water  :  {f(ret)}°F   (ΔT {delta}°F)")
    print(f"  Diff Pressure :  {f(dp)} PSI")
    print(f"  Spray Pump    :  {pump_str}")
    print(f"  CW Pump 1     :  {f(cwp1, 0)}%")
    print(f"  CW Pump 2     :  {f(cwp2, 0)}%")
    print(f"  CT Fan 1      :  {f(ct1, 0)}%")
    print(f"  CT Fan 2      :  {f(ct2, 0)}%")
    print(f"  Basin Level   :  {basin_str}")
    print(f"  Leak Alarm    :  {leak_str}")
except Exception as e:
    print(f"  Could not reach Eclypse BAS: {e}")
PYEOF

# --- Post morning summary to Slack ---
# Load Slack webhook from environment or .env file
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [ -z "$SLACK_WEBHOOK" ] && [ -f "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/.env" ]; then
  SLACK_WEBHOOK=$(grep '^SLACK_WEBHOOK_URL=' "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/.env" | cut -d'=' -f2-)
fi
MORNING_SUMMARY=$(python3 - <<'PYEOF'
import sqlite3, subprocess, json

# Fleet summary from DB
db = "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"
fleet_line = ""
try:
    conn = sqlite3.connect(db)
    row = conn.execute("SELECT scanned_at, total_miners, online, offline, issues FROM scans ORDER BY id DESC LIMIT 1").fetchone()
    if row:
        t, total, online, offline, issues = row
        t = t[:16].replace("T", " ")
        if issues == 0:
            fleet_line = f"✅ All {total} miners healthy ({online} online) — last scan {t}"
        else:
            rows = conn.execute("SELECT action, COUNT(*) FROM miner_readings WHERE scan_id=(SELECT MAX(id) FROM scans) AND action IS NOT NULL GROUP BY action").fetchall()
            amap = dict(rows)
            parts = []
            if amap.get("PDU_CYCLE"): parts.append(f"{amap['PDU_CYCLE']} PDU cycle")
            if amap.get("RESTART"): parts.append(f"{amap['RESTART']} restart")
            if amap.get("RESTART_CHECK_BOARDS"): parts.append(f"{amap['RESTART_CHECK_BOARDS']} dead board")
            if amap.get("MONITOR"): parts.append(f"{amap['MONITOR']} monitor")
            fleet_line = f"⚠️ {total} miners | {online} online | {issues} issues: {', '.join(parts)} — last scan {t}"
    conn.close()
except Exception as e:
    fleet_line = f"Could not read fleet data: {e}"

# HVAC from Eclypse
AUTH = "BigStar:BigSt@r2020"
BASE = "https://192.168.188.235/api/rest/v1/protocols/bacnet/local/objects"
def curl(url):
    r = subprocess.run(["curl","-sk",url,"-u",AUTH,"-L","--max-time","6"], capture_output=True, text=True, timeout=8)
    try: return json.loads(r.stdout)
    except: return None
def prop(t, oid, p):
    d = curl(f"{BASE}/{t}/{oid}/properties/{p}")
    return d.get("value") if d and "value" in d else None
def fv(v, dec=1):
    try: return f"{float(v):.{dec}f}" if v and str(v) != "NaN" else "N/A"
    except: return "N/A"

hvac_line = ""
try:
    sup  = prop("analog-input",  "101", "present-value")
    ret  = prop("analog-input",  "102", "present-value")
    dp   = prop("analog-input",  "103", "present-value")
    cwp2 = prop("analog-output", "102", "present-value")
    ct1  = prop("analog-output", "103", "present-value")
    basin= prop("binary-input",  "302", "present-value")
    leak = prop("binary-value",  "22",  "present-value")
    try: delta = f"{float(ret)-float(sup):.1f}" if sup and ret else "N/A"
    except: delta = "N/A"
    alarms = []
    if str(basin).lower() != "active": alarms.append("🔴 Basin Low")
    if str(leak).lower() == "active":  alarms.append("🔴 Leak!")
    alarm_str = "  ".join(alarms) if alarms else "✅ Clear"
    hvac_line = f"Supply {fv(sup)}°F | Return {fv(ret)}°F | ΔT {delta}°F | DP {fv(dp)} PSI | Pump2 {fv(cwp2,0)}% | Fan1 {fv(ct1,0)}% | Alarms: {alarm_str}"
except Exception as e:
    hvac_line = f"HVAC unavailable: {e}"

msg = f"☀️ *Morning Briefing — {__import__('datetime').datetime.now().strftime('%A %B %d')}*\n"
msg += f"*Fleet:* {fleet_line}\n"
msg += f"*HVAC:* {hvac_line}"
print(msg)
PYEOF
)

curl -s -X POST -H 'Content-type: application/json' \
  --data "{\"text\": \"$MORNING_SUMMARY\"}" \
  "$SLACK_WEBHOOK" > /dev/null

echo ""
echo "========================================"
