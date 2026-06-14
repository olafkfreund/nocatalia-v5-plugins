-- Cloudflare WARP — background service.

noctalia.setUpdateInterval(1000)

local lastCheckTime = 0
local installed = false
local checkedInstalled = false
local connected = false
local mode = ""

local function checkWarpInstalled(callback)
  noctalia.runAsync("which warp-cli", function(res)
    callback(res.exitCode == 0)
  end)
end

local function checkStatus()
  if not installed then return end
  
  noctalia.runAsync("warp-cli status", function(res)
    if res.exitCode == 0 then
      local output = res.stdout or res.body or ""
      local isConnected = output:find("Status update: Connected") or output:find("status update: connected") or output:find("Connected") ~= nil
      
      connected = isConnected
      noctalia.state.set("connected", connected)
      
      local modeMatch = output:match("[Dd]aemon [Mm]ode:%s*(%S+)") or output:match("mode:%s*(%S+)")
      mode = modeMatch or ""
      noctalia.state.set("mode", mode)
      noctalia.state.set("installed", true)
    else
      connected = false
      mode = ""
      noctalia.state.set("connected", false)
      noctalia.state.set("mode", "")
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    local action = if connected then "disconnect" else "connect"
    noctalia.runAsync(`warp-cli {action}`, function(res)
      if res.exitCode == 0 then
        local msg = if action == "connect" then "Connected to WARP" else "Disconnected from WARP"
        noctalia.notify("Cloudflare WARP", msg)
      else
        noctalia.notify("Cloudflare WARP", `Failed to {action}`)
      end
      checkStatus()
    end)
  elseif cmd == "refresh" then
    checkStatus()
  end
end)

function update()
  if not checkedInstalled then
    checkedInstalled = true
    checkWarpInstalled(function(isInst)
      installed = isInst
      noctalia.state.set("installed", installed)
      if installed then
        checkStatus()
      end
    end)
    return
  end

  local now = os.clock()
  local intervalMs = noctalia.getConfig("refreshInterval") or 5000
  local intervalSec = intervalMs / 1000

  if installed and (lastCheckTime == 0 or (now - lastCheckTime >= intervalSec)) then
    lastCheckTime = now
    checkStatus()
  end
end
