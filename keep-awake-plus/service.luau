-- Keep Awake Plus — background service.
-- Controls system sleep inhibition via the bundled system-awake script.

local isActive = false
local remaining = 0
local scope = "partial"
local statusText = ""

local scriptPath = noctalia.pluginDir .. "/scripts/system-awake"

local function updateState()
  noctalia.state.set("isActive", isActive)
  noctalia.state.set("remaining", remaining)
  noctalia.state.set("scope", scope)
  noctalia.state.set("statusText", statusText)
end

local function refreshStatus()
  noctalia.runAsync(scriptPath .. " status --json 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      isActive = false
      remaining = 0
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    -- Parse JSON status
    local activeVal = text:match('"active":(true)') or text:match('"active":(false)')
    local remainVal = text:match('"remaining_seconds":(%d+)')
    local scopeVal = text:match('"scope":"([^"]+)"')
    isActive = activeVal == "true"
    remaining = tonumber(remainVal) or 0
    if scopeVal then scope = scopeVal end
    -- Build status text
    if isActive and remaining > 0 then
      local mins = math.floor(remaining / 60)
      local secs = remaining % 60
      statusText = string.format("%d:%02d", mins, secs)
    elseif isActive then
      statusText = "∞"
    else
      statusText = ""
    end
    updateState()
  end)
end

local function activate(minutes, scopeArg)
  local args = ""
  if minutes and minutes > 0 then
    args = " --duration " .. tostring(minutes)
  end
  if scopeArg and scopeArg ~= "" then
    args = args .. " --scope " .. scopeArg
  end
  noctalia.runAsync(scriptPath .. " activate" .. args .. " 2>/dev/null", function(res)
    refreshStatus()
  end)
end

local function deactivate()
  noctalia.runAsync(scriptPath .. " deactivate 2>/dev/null", function(res)
    refreshStatus()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refreshStatus()
  elseif cmd == "toggle" then
    if isActive then
      deactivate()
    else
      local defaultScope = noctalia.getConfig("defaultScope") or "partial"
      local quickExtend = tonumber(noctalia.getConfig("quickExtendMinutes")) or 30
      activate(quickExtend, defaultScope)
    end
  elseif cmd == "deactivate" then
    deactivate()
  elseif cmd then
    local action, args = cmd:match("^([^:]+):(.*)$")
    if action == "activate" then
      local mins = tonumber(args) or 0
      local defScope = noctalia.getConfig("defaultScope") or "partial"
      activate(mins, defScope)
    end
  end
end)

refreshStatus()

noctalia.setUpdateInterval(5000)

function onUpdate()
  refreshStatus()
end
