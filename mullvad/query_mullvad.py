#!/usr/bin/env python3
import subprocess
import json
import re
import sys
from datetime import datetime

def run_cmd(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout, res.stderr

# Check installed
code, stdout, stderr = run_cmd(["which", "mullvad"])
if code != 0:
    print(json.dumps({"installed": False}))
    sys.exit(0)

# Get status
code, stdout, stderr = run_cmd(["mullvad", "status", "--json"])
if code != 0 or not stdout.strip():
    print(json.dumps({"installed": True, "state": "error"}))
    sys.exit(0)

try:
    status_data = json.loads(stdout)
except Exception:
    status_data = {}

state = status_data.get("state", "disconnected")
details = status_data.get("details", {})
locked = details.get("locked_down", False)

current_location = None
visible_location = None
if state == "connected" and details.get("endpoint"):
    loc = details.get("location", {})
    endpoint = details.get("endpoint", {})
    current_location = {
        "country": loc.get("country", ""),
        "city": loc.get("city", ""),
        "hostname": loc.get("hostname", ""),
        "ipv4": loc.get("ipv4", endpoint.get("address", "")),
        "ipv6": loc.get("ipv6", ""),
        "mullvad_exit_ip": loc.get("mullvad_exit_ip", False)
    }
elif details.get("location"):
    loc = details.get("location", {})
    visible_location = {
        "country": loc.get("country", ""),
        "city": loc.get("city", ""),
        "ipv4": loc.get("ipv4", ""),
        "ipv6": loc.get("ipv6", "")
    }

# Lockdown mode
_, out_lock, _ = run_cmd(["mullvad", "lockdown-mode", "get"])
lockdown = "on" in out_lock.lower()

# Auto connect
_, out_auto, _ = run_cmd(["mullvad", "auto-connect", "get"])
autoconnect = "on" in out_auto.lower()

# LAN sharing
_, out_lan, _ = run_cmd(["mullvad", "lan", "get"])
lan = "allow" if "allow" in out_lan.lower() else "block"

# Relay selection
_, out_relay, _ = run_cmd(["mullvad", "relay", "get"])
relay_selection = {"country": "", "city": "", "hostname": ""}
multihop = False
multihop_entry = ""
ip_version = "any"

for line in out_relay.splitlines():
    line = line.strip()
    if line.startswith("Location:"):
        parts = line[len("Location:"):].strip().split()
        if len(parts) >= 2 and parts[0] == "country":
            relay_selection["country"] = parts[1]
        elif len(parts) >= 3 and parts[0] == "city":
            relay_selection["country"] = parts[1]
            relay_selection["city"] = parts[2]
        elif len(parts) >= 4 and parts[0] == "hostname":
            relay_selection["country"] = parts[1]
            relay_selection["city"] = parts[2]
            relay_selection["hostname"] = parts[3]
    elif line.startswith("Multihop entry:"):
        parts = line[len("Multihop entry:"):].strip().split()
        if len(parts) >= 2 and parts[0] == "country":
            multihop_entry = parts[1]
    elif "multihop state:" in line.lower():
        multihop = "enabled" in line.lower()
    elif "ip protocol:" in line.lower():
        v = line.split(":")[-1].strip().lower()
        ip_version = v if v in ["v4", "v6"] else "any"

# Account
_, out_acc, _ = run_cmd(["mullvad", "account", "get"])
days_left = 9999
account_expiry = ""
m = re.search(r"Expires at:\s+(\S+)", out_acc)
if m:
    account_expiry = m.group(1)
    try:
        exp_date = datetime.strptime(account_expiry, "%Y-%m-%d")
        now = datetime.now()
        days_left = (exp_date - now).days
    except Exception:
        pass

# Relay List (if requested)
relay_list = []
if len(sys.argv) > 1 and sys.argv[1] == "--list-relays":
    _, out_list, _ = run_cmd(["mullvad", "relay", "list"])
    country = None
    city = None
    re_country = re.compile(r"^([^\t].+?)\s+\(([a-z]{2})\)\s*$")
    re_city = re.compile(r"^\t([^\t].+?)\s+\(([a-z0-9]+)\)")
    re_host = re.compile(r"^\t\t(\S+)\s+\(([^,)]+)")
    for line in out_list.splitlines():
        if not line.strip():
            country = None
            city = None
            continue
        m_c = re_country.match(line)
        if m_c:
            country = {"country": m_c.group(1), "code": m_c.group(2), "cities": []}
            relay_list.append(country)
            continue
        m_t = re_city.match(line)
        if m_t and country:
            city = {"city": m_t.group(1), "code": m_t.group(2), "hostnames": []}
            country["cities"].append(city)
            continue
        m_h = re_host.match(line)
        if m_h and city:
            city["hostnames"].append({"name": m_h.group(1), "ipv4": m_h.group(2).strip()})

print(json.dumps({
    "installed": True,
    "state": state,
    "locked": locked,
    "current_location": current_location,
    "visible_location": visible_location,
    "lockdown": lockdown,
    "autoconnect": autoconnect,
    "lan": lan,
    "relay_selection": relay_selection,
    "multihop": multihop,
    "multihop_entry": multihop_entry,
    "ip_version": ip_version,
    "days_left": days_left,
    "relay_list": relay_list
}))
