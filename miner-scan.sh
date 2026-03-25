#!/bin/zsh

# Ask which subnet to scan
echo "Which subnet to scan?"
echo "1) 192.168.188"
echo "2) 192.168.189"
read CHOICE

if [ "$CHOICE" = "1" ]; then
  SUBNET="192.168.188"
elif [ "$CHOICE" = "2" ]; then
  SUBNET="192.168.189"
else
  echo "Invalid choice. Exiting."
  exit 1
fi

echo "Scanning $SUBNET.0/24...\n"

# Loop through every IP from .1 to .254
for i in {1..254}; do
  IP="$SUBNET.$i"
  if ping -c 1 -W 1 $IP &>/dev/null; then
    echo "  ALIVE: $IP"
  fi
done

echo "\nScan complete."
