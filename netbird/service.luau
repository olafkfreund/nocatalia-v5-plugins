-- Netbird — background service.
-- Polls `netbird status --json` and provides connect/disconnect controls.

local connected = false
local ipAddress = ""
local peerCount = 0
local netbirdInstalled = false

local function updateState()
  noctalia.state.set("connected", connected)
  noctalia.state.set("ipAddress", ipAddress)
  noctalia.state.set("peerCount", peerCount)
  noctalia.state.set("netbirdInstalled", netbirdInstalled)
end

local function refresh()
  noctalia.runAsync("netbird status --json 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      connected = false
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    -- Parse key fields from JSON output
    local status = text:match('"status"%s*:%s*"([^"]+)"')
    connected = (status == "Connected" or status == "connected")
    local ip = text:match('"netbirdIp"%s*:%s*"([^"]+)"')
    ipAddress = ip or ""
    -- Count peers by counting "Connected" peers
    local count = 0
    for _ in text:gmatch('"state"%s*:%s*"[Cc]onnected"') do
      count = count + 1
    end
    peerCount = count
    updateState()
  end)
end

local function checkInstalled()
  noctalia.runAsync("which netbird 2>/dev/null", function(res)
    netbirdInstalled = res.exitCode == 0
    updateState()
    if netbirdInstalled then
      refresh()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "up" then
    noctalia.runAsync("netbird up 2>&1", function(res)
      refresh()
    end)
  elseif cmd == "down" then
    noctalia.runAsync("netbird down 2>&1", function(res)
      refresh()
    end)
  elseif cmd == "refresh" then
    refresh()
  end
end)

-- Initial check
checkInstalled()

local refreshInterval = tonumber(noctalia.getConfig("refreshInterval")) or 5000
noctalia.setUpdateInterval(refreshInterval)

function onUpdate()
  if netbirdInstalled then
    refresh()
  end
end
