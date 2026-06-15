#!/usr/bin/env python3
import subprocess
import json
import sys

def busctl_call(obj, itf, method, params=[]):
    cmd = ["busctl", "--user", "call", "--json=short", "org.kde.kdeconnect", obj, itf, method] + params
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None
    try:
        data = json.loads(res.stdout)
        # Handle different output formats of busctl --json
        val = data.get("data", [None])
        if isinstance(val, list) and len(val) > 0:
            return val[0]
        return val
    except Exception:
        return None

def busctl_get(obj, itf, prop):
    cmd = ["busctl", "--user", "get-property", "--json=short", "org.kde.kdeconnect", obj, itf, prop]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None
    try:
        data = json.loads(res.stdout)
        return data.get("data", None)
    except Exception:
        return None

# Check if busctl is available
which_busctl = subprocess.run(["which", "busctl"], capture_output=True)
if which_busctl.returncode != 0:
    print(json.dumps({"available": False, "busctl_available": False, "devices": []}))
    sys.exit(0)

# Check daemon
status = subprocess.run(["busctl", "--user", "status", "org.kde.kdeconnect"], capture_output=True)
if status.returncode != 0:
    print(json.dumps({"available": False, "busctl_available": True, "devices": []}))
    sys.exit(0)

device_ids = busctl_call("/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices")
if not device_ids:
    print(json.dumps({"available": True, "busctl_available": True, "devices": []}))
    sys.exit(0)

devices = []
for dev_id in device_ids:
    dev_path = f"/modules/kdeconnect/devices/{dev_id}"
    name = busctl_get(dev_path, "org.kde.kdeconnect.device", "name") or "Unknown"
    reachable = busctl_get(dev_path, "org.kde.kdeconnect.device", "isReachable") == True
    paired = busctl_get(dev_path, "org.kde.kdeconnect.device", "isPaired") == True
    pair_requested = busctl_get(dev_path, "org.kde.kdeconnect.device", "isPairRequested") == True
    verification_key = busctl_get(dev_path, "org.kde.kdeconnect.device", "verificationKey") or ""
    
    battery = -1
    charging = False
    net_type = ""
    net_strength = -1
    notifications = []
    
    if reachable and paired:
        bat_val = busctl_get(f"{dev_path}/battery", "org.kde.kdeconnect.device.battery", "charge")
        if bat_val is not None:
            battery = bat_val
        charging = busctl_get(f"{dev_path}/battery", "org.kde.kdeconnect.device.battery", "isCharging") == True
        net_val = busctl_get(f"{dev_path}/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType")
        if net_val:
            net_type = net_val
        strength_val = busctl_get(f"{dev_path}/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength")
        if strength_val is not None:
            net_strength = strength_val
            
        active_notifs = busctl_call(f"{dev_path}/notifications", "org.kde.kdeconnect.device.notifications", "activeNotifications")
        if isinstance(active_notifs, list):
            notifications = active_notifs

    devices.append({
        "id": dev_id,
        "name": name,
        "reachable": reachable,
        "paired": paired,
        "pairRequested": pair_requested,
        "verificationKey": verification_key,
        "battery": battery,
        "charging": charging,
        "cellularNetworkType": net_type,
        "cellularNetworkStrength": net_strength,
        "notificationIds": notifications
    })

print(json.dumps({"available": True, "busctl_available": True, "devices": devices}))
