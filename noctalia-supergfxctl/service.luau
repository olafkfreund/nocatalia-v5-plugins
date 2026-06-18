-- noctalia-supergfxctl — background service.
-- Polls GPU mode via `supergfxctl --get` and allows mode switching.

local currentMode = "unknown"
local pendingMode = ""
local supported = false
local version = ""

local MODES = {
  "Integrated",
  "Hybrid",
  "NvidiaNoModeset",
  "Vfio",
  "AsusEgpu",
  "AsusMuxDgpu",
}

local function updateState()
  noctalia.state.set("currentMode", currentMode)
  noctalia.state.set("pendingMode", pendingMode)
  noctalia.state.set("supported", supported)
  noctalia.state.set("version", version)
end

local function refresh()
  noctalia.runAsync("supergfxctl --version --get --pend-mode 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      supported = false
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    local lines = {}
    for line in text:gmatch("[^\n]+") do
      lines[#lines + 1] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if #lines >= 1 then version = lines[1] end
    if #lines >= 2 then currentMode = lines[2] end
    if #lines >= 3 then
      pendingMode = lines[3]
      if pendingMode == "None" then pendingMode = "" end
    end
    supported = true
    updateState()
  end)
end

local function setMode(mode)
  noctalia.runAsync("supergfxctl --mode " .. mode .. " 2>/dev/null", function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd then
    if cmd == "refresh" then
      refresh()
    elseif cmd:sub(1, 8) == "setMode:" then
      local mode = cmd:sub(9)
      setMode(mode)
    else
      setMode(cmd)
    end
  end
end)

refresh()

local pollInterval = tonumber(noctalia.getConfig("pollingInterval")) or 3000
noctalia.setUpdateInterval(pollInterval)

function onUpdate()
  refresh()
end
