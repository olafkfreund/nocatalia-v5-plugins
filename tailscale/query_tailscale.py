#!/usr/bin/env python3
import subprocess
import json
import sys

def run_cmd(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout, res.stderr

# Check installed
code, stdout, stderr = run_cmd(["which", "tailscale"])
if code != 0:
    print(json.dumps({"installed": False}))
    sys.exit(0)

# Get status
code, stdout, stderr = run_cmd(["tailscale", "status", "--json"])
if code != 0 or not stdout.strip():
    print(json.dumps({"installed": True, "running": False, "tailscaleStatus": "Disconnected"}))
    sys.exit(0)

try:
    data = json.loads(stdout)
except Exception:
    data = {}

backend_state = data.get("BackendState", "Disconnected")
running = backend_state == "Running"
needs_login = backend_state == "NeedsLogin"

auth_url = data.get("AuthURL", "")
self_ips = data.get("Self", {}).get("TailscaleIPs", [])
ipv4_ips = [ip for ip in self_ips if ip.startswith("100.")]
tailscale_ip = ipv4_ips[0] if ipv4_ips else (self_ips[0] if self_ips else "")

tailscale_status = "Disconnected"
if needs_login:
    tailscale_status = "NeedsLogin"
elif running:
    tailscale_status = "Connected"

peers = []
peer_map = data.get("Peer", {})
for peer_id, peer in peer_map.items():
    p_ips = peer.get("TailscaleIPs", [])
    p_ipv4s = [ip for ip in p_ips if ip.startswith("100.")]
    
    host_name = peer.get("HostName", "")
    dns_name = peer.get("DNSName", "")
    if host_name.lower() == "localhost" and dns_name:
        label = dns_name.split(".")[0]
        if label:
            host_name = label
            
    peers.append({
        "HostName": host_name,
        "DNSName": dns_name,
        "TailscaleIPs": p_ipv4s,
        "Online": peer.get("Online", False),
        "OS": peer.get("OS", ""),
        "Tags": peer.get("Tags") or [],
        "ExitNodeOption": peer.get("ExitNodeOption", False),
        "ExitNode": peer.get("ExitNode", False)
    })

exit_node_status = None
ens = data.get("ExitNodeStatus")
if ens:
    exit_node_status = {
        "ID": ens.get("ID", ""),
        "Online": ens.get("Online", False),
        "TailscaleIPs": ens.get("TailscaleIPs") or []
    }

# Get accounts list
accounts = []
current_account_id = ""
code_acc, stdout_acc, stderr_acc = run_cmd(["tailscale", "switch", "--list", "--json"])
if code_acc == 0 and stdout_acc.strip():
    try:
        accounts = json.loads(stdout_acc)
        for acc in accounts:
            if acc.get("selected"):
                current_account_id = acc.get("id", "")
    except Exception:
        pass

print(json.dumps({
    "installed": True,
    "running": running,
    "needsLogin": needs_login,
    "backendState": backend_state,
    "authUrl": auth_url,
    "tailscaleIp": tailscale_ip,
    "tailscaleStatus": tailscale_status,
    "peerCount": len(peers),
    "peers": peers,
    "exitNodeStatus": exit_node_status,
    "accounts": accounts,
    "currentAccountId": current_account_id
}))
