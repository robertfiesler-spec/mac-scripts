#!/bin/zsh
# ============================================
# morning.sh
# Daily morning briefing for Rob Fiesler
# BiXBiT USA
# 
# Updated: April 13, 2026
# Now pulls Mining Guardian data from VPS
# ============================================

LOG_FILE="/Users/BigBobby/morning-log.txt"

# Keep Mac awake for duration of this script
caffeinate -i -w $$ &

# Start capturing to log file
exec > >(tee "$LOG_FILE") 2>&1

# --- Header ---
echo "========================================"
echo "  GOOD MORNING, ROB"
echo "  $(date '+%A, %B %d %Y')"
echo "========================================"

# --- Bitcoin Price ---
echo ""
echo "💰 BITCOIN"
BTC_JSON=$(curl -s "https://api.coinbase.com/v2/prices/BTC-USD/spot" 2>/dev/null)
if [ -n "$BTC_JSON" ]; then
  BTC_PRICE=$(echo "$BTC_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('\$' + '{:,}'.format(int(float(d['data']['amount']))))" 2>/dev/null)
  echo "  Price:  $BTC_PRICE"
else
  echo "  Price:  Could not fetch"
fi

# --- System (Mac) ---
echo ""
echo "⚙️  MAC SYSTEM"
