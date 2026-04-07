#!/bin/zsh
# ============================================
# fleet.sh
# Quick miner fleet summary pulled directly
# from Mining Guardian's SQLite database.
# Shows fleet health, recent issues, and the
# top troubled miners — without opening the app.
# Author: Rob Fiesler | BiXBiT USA
# Usage: ./fleet.sh
# ============================================

CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
GREEN="\033[1;32m"
RESET="\033[0m"

DB="/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"

printf "\n${CYAN}========================================${RESET}\n"
printf "${CYAN}  ⛏️   MINER FLEET STATUS${RESET}\n"
printf "${CYAN}  $(date '+%A %b %d, %Y  %I:%M %p')${RESET}\n"
printf "${CYAN}========================================${RESET}\n\n"

if [[ ! -f "$DB" ]]; then
  printf "  ${RED}No database found at:${RESET}\n"
  printf "  $DB\n"
  printf "  Run Mining Guardian first.\n\n"
  exit 1
fi

python3 - <<'PYEOF'
import sqlite3

GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

db = "/Users/BigBobby/Documents/GitHub/Mining Gaurdian/guardian.db"
conn = sqlite3.connect(db)

# ── Last scan summary ────────────────────────────────────────────────
# The scans table stores one row per Guardian run with totals.
row = conn.execute("""
    SELECT id, scanned_at, total_miners, online, offline, issues
    FROM scans ORDER BY id DESC LIMIT 1
""").fetchone()

if not row:
    print("  No scan data yet — run Mining Guardian first.")
    conn.close()
    exit()

scan_id, scanned_at, total, online, offline, issues = row
t = scanned_at[:16].replace("T", " ")

print(f"  Last scan   :  {t}")
print(f"  Fleet size  :  {total} miners")

# Color-code online/offline counts
online_str  = f"{GREEN}{online} online{RESET}"
offline_str = f"{RED}{offline} offline{RESET}" if offline > 0 else f"{GREEN}{offline} offline{RESET}"
print(f"  Status      :  {online_str}  |  {offline_str}")

# ── Issue breakdown ──────────────────────────────────────────────────
if issues == 0:
    print(f"\n  {GREEN}✅ All miners healthy — no action required.{RESET}")
else:
    print(f"\n  {YELLOW}⚠️  {issues} issue(s) flagged:{RESET}")

    action_rows = conn.execute("""
        SELECT action, COUNT(*) as cnt
        FROM miner_readings
        WHERE scan_id = ? AND action IS NOT NULL
        GROUP BY action
        ORDER BY cnt DESC
    """, (scan_id,)).fetchall()

    # Friendly names for action codes
    labels = {
        "PDU_CYCLE":             "🔌 PDU cycle needed",
        "RESTART":               "🔄 Firmware restart",
        "RESTART_CHECK_BOARDS":  "🛠️  Dead board detected",
        "TEMP_ACTION_REQUIRED":  "🌡️  High temp",
        "MONITOR":               "👁️  Flagged for monitoring",
    }

    for action, count in action_rows:
        label = labels.get(action, action)
        print(f"    {label}:  {count}")

# ── Troubled miners (top 5) ──────────────────────────────────────────
# Show the specific miners that need attention
troubled = conn.execute("""
    SELECT ip_address, action, hashrate, temp
    FROM miner_readings
    WHERE scan_id = ? AND action IS NOT NULL AND action != 'MONITOR'
    ORDER BY action
    LIMIT 5
""", (scan_id,)).fetchall()

if troubled:
    print(f"\n  {CYAN}Miners needing attention:{RESET}")
    for ip, action, hashrate, temp in troubled:
        hr_str = f"{float(hashrate):.1f} TH/s" if hashrate else "N/A"
        tmp_str = f"{temp}°C" if temp else "N/A"
        label = {
            "PDU_CYCLE":             "PDU",
            "RESTART":               "Restart",
            "RESTART_CHECK_BOARDS":  "Dead Board",
            "TEMP_ACTION_REQUIRED":  "Overtemp",
        }.get(action, action)
        print(f"    {ip:<18}  [{label}]   {hr_str}   {tmp_str}")

# ── Last 5 scans trend ───────────────────────────────────────────────
# A quick look at whether fleet health is improving or degrading
recent = conn.execute("""
    SELECT scanned_at, online, total_miners, issues
    FROM scans ORDER BY id DESC LIMIT 5
""").fetchall()

if len(recent) > 1:
    print(f"\n  {CYAN}Recent scans:{RESET}")
    for r in reversed(recent):
        ts, on, tot, iss = r
        ts = ts[:16].replace("T", " ")
        flag = "✅" if iss == 0 else f"⚠️  {iss} issues"
        print(f"    {ts}   {on}/{tot} online   {flag}")

conn.close()
PYEOF

printf "\n${CYAN}========================================${RESET}\n\n"
