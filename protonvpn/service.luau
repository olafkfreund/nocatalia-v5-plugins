-- ProtonVPN — background service.
-- Polls `protonvpn status` and provides connect/disconnect via state commands.

local vpnStatus = "unknown"
local serverName = ""
local serverLocation = ""
local protocol = ""
local serverLoad = -1
local killSwitch = "unknown"
local isLoading = true

local function updateState()
  noctalia.state.set("vpnStatus", vpnStatus)
  noctalia.state.set("serverName", serverName)
  noctalia.state.set("serverLocation", serverLocation)
  noctalia.state.set("protocol", protocol)
  noctalia.state.set("serverLoad", serverLoad)
  noctalia.state.set("killSwitch", killSwitch)
  noctalia.state.set("isLoading", isLoading)
end

local function refresh()
  noctalia.runAsync("protonvpn status 2>/dev/null", function(res)
    isLoading = false
    local text = (res.stdout or res.body or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local statusMatch = text:match("[Ss]tatus:%s*(%S+)")
    if not statusMatch then
      vpnStatus = "unknown"
      updateState()
      return
    end
    if statusMatch:lower() == "connected" then
      vpnStatus = "connected"
      local server, location = text:match("[Ss]erver:%s*(%S+)%s+in%s+(.+)\n")
      serverName = server or ""
      serverLocation = location and location:gsub("%s+$", "") or ""
      local proto = text:match("[Pp]rotocol:%s*(%S+)")
      protocol = proto or ""
      local load = text:match("[Ll]oad:%s*(%d+)")
      serverLoad = load and tonumber(load) or -1
    else
      vpnStatus = "disconnected"
      serverName = ""
      serverLocation = ""
      protocol = ""
      serverLoad = -1
    end
    updateState()
  end)
end

local function runAction(cmd)
  noctalia.runAsync(cmd, function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "connect" then
    runAction("protonvpn connect 2>&1")
  elseif cmd == "disconnect" then
    runAction("protonvpn disconnect 2>&1")
  elseif cmd == "connect-securecore" then
    runAction("protonvpn connect --securecore 2>&1")
  elseif cmd == "connect-p2p" then
    runAction("protonvpn connect --p2p 2>&1")
  elseif cmd == "refresh" then
    refresh()
  end
end)

-- Initial poll
refresh()

local pollInterval = tonumber(noctalia.getConfig("pollInterval")) or 5000
noctalia.setUpdateInterval(pollInterval)

function onUpdate()
  refresh()
end
