#!/bin/zsh
# ============================================
# health-check.sh
# System health check script for macOS
# Author: Rob Fiesler | BiXBiT USA
# ============================================

echo "========================================"
echo "  SYSTEM HEALTH CHECK"
echo "  $(date)"
echo "========================================"

# --- Disk Usage ---
echo "\n📦 DISK USAGE"
df -h / | awk 'NR==2 {print "  Used: " $3 " / " $2 " (" $5 " full)"}'

# --- Memory Usage ---
echo "\n🧠 MEMORY"
vm_stat | awk '
  /Pages free/     { free=$3 }
  /Pages active/   { active=$3 }
  /Pages inactive/ { inactive=$3 }
  END {
    used=(active+inactive)*4096/1073741824
    avail=free*4096/1073741824
    printf "  Used: %.2f GB | Available: %.2f GB\n", used, avail
  }'

# --- Network ---
echo "\n🌐 NETWORK"
if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
  echo "  Internet: Connected"
else
  echo "  Internet: No connection"
fi

# --- Uptime ---
echo "\n UPTIME"
uptime | awk '{print "  " $0}'

echo "\n========================================"
echo "  Done."
echo "========================================"
