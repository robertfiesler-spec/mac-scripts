#!/bin/zsh
# ============================================
# btc.sh
# Quick Bitcoin price check — current spot
# price from Coinbase plus a 24h comparison
# from CoinGecko so you know if you're up or down.
# Author: Rob Fiesler | BiXBiT USA
# Usage: ./btc.sh
# ============================================

# --- Colors ---
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

printf "\n${CYAN}========================================${RESET}\n"
printf "${CYAN}  ₿  BITCOIN PRICE CHECK${RESET}\n"
printf "${CYAN}  $(date '+%A %b %d, %Y  %I:%M %p')${RESET}\n"
printf "${CYAN}========================================${RESET}\n\n"

# --- Current spot price from Coinbase ---
# Coinbase's public API needs no API key for spot price.
# It returns JSON: {"data": {"amount": "67432.15", "currency": "USD"}}
BTC_RAW=$(curl -s --max-time 5 "https://api.coinbase.com/v2/prices/BTC-USD/spot")

if [[ -z "$BTC_RAW" ]]; then
  printf "  ${RED}Could not reach Coinbase API.${RESET}\n\n"
  exit 1
fi

# --- 24h change from CoinGecko ---
# CoinGecko's free API returns current price + 24h % change.
# price_change_percentage_24h is a float like 2.35 (meaning +2.35%)
GECKO_RAW=$(curl -s --max-time 5 \
  "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")

python3 - <<PYEOF
import json, sys

# Parse Coinbase spot price
cb = json.loads('''$BTC_RAW''')
price = float(cb['data']['amount'])

# Parse CoinGecko 24h change
try:
    cg = json.loads('''$GECKO_RAW''')
    change_24h = cg['bitcoin']['usd_24h_change']
    direction = "▲" if change_24h >= 0 else "▼"
    color = "\033[1;32m" if change_24h >= 0 else "\033[1;31m"
    change_str = f"{color}{direction} {abs(change_24h):.2f}% (24h)\033[0m"
except Exception:
    change_str = "\033[1;33m  24h change unavailable\033[0m"

# Format price with commas
formatted = f"\${price:,.0f}"

print(f"  Price:     \033[1;33m{formatted}\033[0m   {change_str}")

# Quick context — milestone markers
if price >= 100000:
    print(f"\n  \033[1;32m🚀 ABOVE \$100K — we're in the big leagues.\033[0m")
elif price >= 80000:
    print(f"\n  \033[1;32m🔥 Strong — holding above \$80K.\033[0m")
elif price >= 60000:
    print(f"\n  \033[1;33m📈 Solid range — mid \$60K–\$80K.\033[0m")
elif price >= 40000:
    print(f"\n  \033[1;33m⚠️  Below \$60K — keep an eye on it.\033[0m")
else:
    print(f"\n  \033[1;31m📉 Below \$40K — rough patch.\033[0m")

PYEOF

printf "\n${CYAN}========================================${RESET}\n\n"
