-- Network Manager VPN — background service.
-- Monitors VPN connections via nmcli and provides connect/disconnect.

local connections = {}
local activeVpn = ""
local activeUuid = ""
local connected = false

local function updateState()
  noctalia.state.set("connected", connected)
  noctalia.state.set("activeVpn", activeVpn)
  noctalia.state.set("connectionCount", #connections)
end

local function refresh()
  -- Get all VPN connections
  noctalia.runAsync("nmcli -t -f NAME,TYPE,STATE,UUID connection show 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      connected = false
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    local vpns = {}
    local activeFound = false
    for line in text:gmatch("[^\n]+") do
      local name, ctype, state, uuid = line:match("^([^:]+):([^:]+):([^:]+):([^:]+)$")
      if name and ctype and state and uuid then
        if ctype:match("vpn") or ctype:match("wireguard") or ctype:match("openvpn") or ctype:match("libreswan") then
          vpns[#vpns + 1] = {name = name, type = ctype, state = state, uuid = uuid}
          if state == "activated" then
            activeVpn = name
            activeUuid = uuid
            activeFound = true
          end
        end
      end
    end
    connections = vpns
    if not activeFound then
      activeVpn = ""
      activeUuid = ""
    end
    connected = activeFound
    updateState()
  end)
end

local function connectVpn(uuid)
  noctalia.runAsync("nmcli connection up uuid " .. uuid .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function disconnectVpn(uuid)
  noctalia.runAsync("nmcli connection down uuid " .. uuid .. " 2>/dev/null", function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "toggle" then
    if connected and activeUuid ~= "" then
      disconnectVpn(activeUuid)
    elseif #connections > 0 then
      connectVpn(connections[1].uuid)
    end
  elseif cmd then
    local action, uuid = cmd:match("^([^:]+):(.+)$")
    if action == "connect" then
      connectVpn(uuid)
    elseif action == "disconnect" then
      disconnectVpn(uuid)
    end
  end
end)

refresh()

noctalia.setUpdateInterval(5000)

function onUpdate()
  refresh()
end
