#!/usr/bin/env python3
"""
hvac_collector.py — Multi-System HVAC Data Collector
Runs on Mac, pushes data to Mining Guardian VPS

Polls both HVAC systems (warehouse + S19J Pro) and sends to VPS API.
Run via launchd for automatic 5-minute collection.

Created: April 13, 2026
"""

import subprocess
import json
import logging
import sys
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/Users/BigBobby/Library/Logs/hvac_collector.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# VPS endpoint
VPS_API = "http://187.124.247.182:8585/api/hvac/ingest"

# Eclypse credentials
ECLYPSE_USER = "BigStar"
ECLYPSE_PASS = "BigSt@r2020"

# System configurations
SYSTEMS = {
    "warehouse": {
        "ip": "192.168.188.235",
        "name": "Warehouse HVAC",
        "points": {
            "supply_temp":    ("analog-input",  "101"),
            "return_temp":    ("analog-input",  "102"),
            "diff_pressure":  ("analog-input",  "103"),
            "spray_pump":     ("binary-input",  "208"),
            "leak_alarm":     ("binary-value",  "22"),
            "basin_level":    ("binary-input",  "302"),
            "cwp1_vfd":       ("analog-output", "101"),
            "cwp2_vfd":       ("analog-output", "102"),
            "ct1_vfd":        ("analog-output", "103"),
            "ct2_vfd":        ("analog-output", "104"),
        }
    },
    "s19jpro": {
        "ip": "192.168.189.235",
        "name": "S19J Pro Container",
        "points": {
            "supply_temp":    ("analog-input",  "105"),  # CDWST
            "return_temp":    ("analog-input",  "106"),  # CDWRT
            "outside_air":    ("analog-input",  "107"),  # OAT
            "container_temp": ("analog-input",  "108"),  # ContainerSpaceTemp
            "cwp1_fdbk":      ("analog-input",  "102"),  # CWP1_Fdbk
            "cwp2_fdbk":      ("analog-input",  "103"),  # CWP2_Fdbk
            "ct1_vfd":        ("analog-output", "101"),  # CT1_VFD
            "ct2_vfd":        ("analog-output", "102"),  # CT2_VFD
            "leak_alarm":     ("binary-input",  "301"),
            "basin_level":    ("binary-input",  "302"),
        }
    }
}


def curl_get(ip: str, obj_type: str, oid: str) -> Optional[str]:
    """Fetch a BACnet property value from Eclypse controller."""
    url = f"https://{ip}/api/rest/v1/protocols/bacnet/local/objects/{obj_type}/{oid}/properties/present-value"
    try:
        result = subprocess.run(
            ["curl", "-sk", url, "-u", f"{ECLYPSE_USER}:{ECLYPSE_PASS}", 
             "-L", "--max-time", "6"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout:
            data = json.loads(result.stdout)
            return data.get("value")
    except Exception as e:
        logger.debug(f"curl_get failed for {ip}/{obj_type}/{oid}: {e}")
    return None


def to_float(v) -> Optional[float]:
    """Convert value to float, handling NaN."""
    try:
        f = float(v)
        return None if f != f else round(f, 2)
    except (TypeError, ValueError):
        return None


def is_active(v) -> Optional[bool]:
    """Check if binary value is active."""
    if v is None:
        return None
    return str(v).strip().lower() == "active"


def poll_system(system_id: str) -> Dict[str, Any]:
    """Poll a single HVAC system and return readings."""
    cfg = SYSTEMS[system_id]
    ip = cfg["ip"]
    points = cfg["points"]
    
    readings = {}
    
    # Fetch all points
    vals = {}
    for key, (obj_type, oid) in points.items():
        vals[key] = curl_get(ip, obj_type, oid)
    
    # Build readings dict
    readings["supply_temp_f"] = to_float(vals.get("supply_temp"))
    readings["return_temp_f"] = to_float(vals.get("return_temp"))
    readings["diff_pressure_psi"] = to_float(vals.get("diff_pressure"))
    readings["outside_air_f"] = to_float(vals.get("outside_air"))
    readings["container_temp_f"] = to_float(vals.get("container_temp"))
    
    # Calculate delta T
    if readings["supply_temp_f"] and readings["return_temp_f"]:
        readings["delta_t_f"] = round(readings["return_temp_f"] - readings["supply_temp_f"], 2)
    
    # Pump/fan speeds
    if system_id == "warehouse":
        readings["cwp1_vfd_pct"] = to_float(vals.get("cwp1_vfd"))
        readings["cwp2_vfd_pct"] = to_float(vals.get("cwp2_vfd"))
    else:
        readings["cwp1_vfd_pct"] = to_float(vals.get("cwp1_fdbk"))
        readings["cwp2_vfd_pct"] = to_float(vals.get("cwp2_fdbk"))
    
    readings["ct1_vfd_pct"] = to_float(vals.get("ct1_vfd"))
    readings["ct2_vfd_pct"] = to_float(vals.get("ct2_vfd"))
    
    # Alarms
    readings["leak_alarm"] = is_active(vals.get("leak_alarm"))
    readings["basin_level_ok"] = is_active(vals.get("basin_level"))
    
    return readings


def push_to_vps(system_id: str, readings: Dict[str, Any]) -> bool:
    """Push readings to VPS API."""
    payload = {
        "system_id": system_id,
        "readings": readings,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    try:
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", VPS_API,
             "-H", "Content-Type: application/json",
             "-d", json.dumps(payload),
             "--max-time", "10"],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            resp = json.loads(result.stdout)
            if resp.get("status") == "ok":
                return True
            logger.warning(f"VPS response: {resp}")
    except Exception as e:
        logger.error(f"push_to_vps failed for {system_id}: {e}")
    return False


def main():
    """Main collection loop."""
    logger.info("=" * 50)
    logger.info("HVAC Collector starting")
    
    success_count = 0
    for system_id in SYSTEMS:
        logger.info(f"Polling {system_id}...")
        try:
            readings = poll_system(system_id)
            
            # Log summary
            sup = readings.get("supply_temp_f", "N/A")
            ret = readings.get("return_temp_f", "N/A")
            dlt = readings.get("delta_t_f", "N/A")
            logger.info(f"  {system_id}: Supply={sup}°F, Return={ret}°F, ΔT={dlt}°F")
            
            # Push to VPS
            if push_to_vps(system_id, readings):
                logger.info(f"  ✓ Pushed {system_id} to VPS")
                success_count += 1
            else:
                logger.warning(f"  ✗ Failed to push {system_id}")
                
        except Exception as e:
            logger.error(f"Error polling {system_id}: {e}")
    
    logger.info(f"Collection complete: {success_count}/{len(SYSTEMS)} systems")
    return success_count == len(SYSTEMS)


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
