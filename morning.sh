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

# --- Post morning summary to Slack ---
# Load Slack webhook from environment or .env file
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [ -z "$SLACK_WEBHOOK" ] && [ -f "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/.env" ]; then
  SLACK_WEBHOOK=$(grep '^SLACK_WEBHOOK_URL=' "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/.env" | cut -d'=' -f2-)
fi
MORNING_SUMMARY=$(python3 - <<'PYEOF'
import sqlite3
db = "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"
try:
    conn = sqlite3.connect(db)
    row = conn.execute("SELECT scanned_at, total_miners, online, offline, issues FROM scans ORDER BY id DESC LIMIT 1").fetchone()
    if row:
        t, total, online, offline, issues = row
        t = t[:16].replace("T", " ")
        if issues == 0:
            print(f"☀️ *Morning Briefing — Fleet Status*\nLast scan: {t}\n✅ All {total} miners healthy ({online} online)")
        else:
            rows = conn.execute("SELECT action, COUNT(*) FROM miner_readings WHERE scan_id=(SELECT MAX(id) FROM scans) AND action IS NOT NULL GROUP BY action").fetchall()
            amap = dict(rows)
            parts = []
            if amap.get("PDU_CYCLE"): parts.append(f"{amap['PDU_CYCLE']} PDU cycle")
            if amap.get("RESTART"): parts.append(f"{amap['RESTART']} firmware restart")
            if amap.get("TEMP_ACTION_REQUIRED"): parts.append(f"{amap['TEMP_ACTION_REQUIRED']} high temp")
            if amap.get("MONITOR"): parts.append(f"{amap['MONITOR']} monitor")
            print(f"☀️ *Morning Briefing — Fleet Status*\nLast scan: {t}\n⚠️ {total} miners | {online} online | {offline} offline | {issues} issues: {', '.join(parts)}")
    conn.close()
except Exception as e:
    print(f"☀️ *Morning Briefing* — Could not read fleet data: {e}")
PYEOF
)

curl -s -X POST -H 'Content-type: application/json' \
  --data "{\"text\": \"$MORNING_SUMMARY\"}" \
  "$SLACK_WEBHOOK" > /dev/null

echo ""
echo "========================================"
