#!/bin/zsh
# ============================================
# hvac.sh
# Standalone warehouse HVAC status check
# Pulls live data from the Eclypse BAS controller
# at 192.168.188.235 via BACnet REST API.
# Author: Rob Fiesler | BiXBiT USA
# Usage: ./hvac.sh
# ============================================

CYAN="\033[1;36m"
RESET="\033[0m"

printf "\n${CYAN}========================================${RESET}\n"
printf "${CYAN}  🏭  WAREHOUSE MECHANICAL${RESET}\n"
printf "${CYAN}  $(date '+%A %b %d, %Y  %I:%M %p')${RESET}\n"
printf "${CYAN}========================================${RESET}\n\n"

python3 - <<'PYEOF'
import subprocess, json

AUTH = "BigStar:BigSt@r2020"
BASE = "https://192.168.188.235/api/rest/v1/protocols/bacnet/local/objects"

def get(url):
    """Hit the Eclypse REST API with curl (avoids SSL cert issues with -sk)."""
    r = subprocess.run(
        ["curl", "-sk", url, "-u", AUTH, "-L", "--max-time", "6"],
        capture_output=True, text=True, timeout=8
    )
    try:
        return json.loads(r.stdout)
    except:
        return None

def prop(obj_type, obj_id, prop_name):
    """Fetch a single BACnet property value."""
    d = get(f"{BASE}/{obj_type}/{obj_id}/properties/{prop_name}")
    return d.get("value") if d and "value" in d else None

def fmt(val, decimals=1):
    """Format a float value, or return N/A if unavailable."""
    try:
        return f"{float(val):.{decimals}f}" if val and str(val) != "NaN" else "N/A"
    except:
        return "N/A"

def status_icon(val, on_state="active"):
    """Return green ON or red OFF based on binary value."""
    return "🟢 ON" if str(val).lower() == on_state else "🔴 OFF"

try:
    # Fetch all the points we care about
    sup   = prop("analog-input",  "101", "present-value")   # Supply water temp
    ret   = prop("analog-input",  "102", "present-value")   # Return water temp
    dp    = prop("analog-input",  "103", "present-value")   # Differential pressure
    pump  = prop("binary-input",  "208", "present-value")   # Spray pump status
    basin = prop("binary-input",  "302", "present-value")   # Basin level OK
    leak  = prop("binary-value",  "22",  "present-value")   # Leak alarm
    cwp1  = prop("analog-output", "101", "present-value")   # CW Pump 1 speed %
    cwp2  = prop("analog-output", "102", "present-value")   # CW Pump 2 speed %
    ct1   = prop("analog-output", "103", "present-value")   # Cooling Tower Fan 1 %
    ct2   = prop("analog-output", "104", "present-value")   # Cooling Tower Fan 2 %

    # Delta T = return minus supply (how hard the system is working)
    # A higher delta T means the miners are pulling more heat out of the water
    try:
        delta = f"{float(ret) - float(sup):.1f}" if sup and ret else "N/A"
    except:
        delta = "N/A"

    pump_str  = status_icon(pump)
    basin_str = "🟢 OK" if str(basin).lower() == "active" else "🔴 LOW"
    leak_str  = "🔴 LEAK ALARM" if str(leak).lower() == "active" else "✅ Clear"

    print(f"  Supply Water  :  {fmt(sup)}°F")
    print(f"  Return Water  :  {fmt(ret)}°F   (ΔT {delta}°F)")
    print()
    print(f"  Diff Pressure :  {fmt(dp)} PSI")
    print(f"  Spray Pump    :  {pump_str}")
    print(f"  Basin Level   :  {basin_str}")
    print()
    print(f"  CW Pump 1     :  {fmt(cwp1, 0)}%")
    print(f"  CW Pump 2     :  {fmt(cwp2, 0)}%")
    print(f"  CT Fan 1      :  {fmt(ct1, 0)}%")
    print(f"  CT Fan 2      :  {fmt(ct2, 0)}%")
    print()
    print(f"  Leak Alarm    :  {leak_str}")

except Exception as e:
    print(f"  ❌ Could not reach Eclypse BAS: {e}")

PYEOF

printf "\n${CYAN}========================================${RESET}\n\n"
