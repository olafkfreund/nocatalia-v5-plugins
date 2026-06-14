-- Battery Actions — background service.
-- Periodically checks UPower status and runs user commands on state transitions.

noctalia.setUpdateInterval(5000) -- Check battery status every 5 seconds

local lastOnBattery = nil

local function getUPowerInfo(callback)
  noctalia.runAsync("upower -d", function(res)
    if res.exitCode ~= 0 then return end
    
    local output = res.stdout or res.body or ""
    local onBattery = false
    local percentage = "0"
    local state = "unknown"
    local rate = "0"
    local path = "/org/freedesktop/UPower/devices/DisplayDevice"

    local onBatMatch = output:match("[Oo]n%-[Bb]attery:%s*(%S+)")
    if onBatMatch then
      onBattery = (onBatMatch:lower() == "yes")
    end

    local deviceBlock = output:match("Device:%s*(.-)Daemon:") or output
    
    path = deviceBlock:match("^%s*(%S+)") or path
    percentage = deviceBlock:match("percentage:%s*(%d+)%%") or percentage
    state = deviceBlock:match("state:%s*(%S+)") or state
    rate = deviceBlock:match("energy%-rate:%s*(%S+)") or deviceBlock:match("charge%-rate:%s*(%S+)") or rate

    callback({
      onBattery = onBattery,
      percentage = percentage,
      state = state,
      rate = rate,
      path = path
    })
  end)
end

local function executeAction(script, info)
  if not script or script == "" then return end

  -- Properly escape single quotes in environment variables and command
  local envCmd = string.format(
    "env BAT_PERCENTAGE=%q BAT_STATE=%q BAT_RATE=%q BAT_PATH=%q sh -c %q",
    info.percentage,
    info.state,
    info.rate,
    info.path,
    script
  )

  noctalia.log(`BatteryActions: Running script with cmd: {envCmd}`)
  noctalia.runAsync(envCmd, function(res)
    if res.exitCode ~= 0 then
      noctalia.log(`BatteryActions Error: Script exited with code {res.exitCode}. Stderr: {res.stderr or ""}`)
    end
  end)
end

function update()
  getUPowerInfo(function(info)
    if lastOnBattery == nil then
      -- First run, execute initial state
      lastOnBattery = info.onBattery
      local scriptKey = if info.onBattery then "onBatteryScript" else "pluggedInScript"
      local script = noctalia.getConfig(scriptKey) or ""
      executeAction(script, info)
    elseif info.onBattery ~= lastOnBattery then
      -- State transitioned
      lastOnBattery = info.onBattery
      local stateStr = if info.onBattery then "On Battery" else "Plugged In"
      noctalia.log(`BatteryActions: State changed to {stateStr}`)
      
      local scriptKey = if info.onBattery then "onBatteryScript" else "pluggedInScript"
      local script = noctalia.getConfig(scriptKey) or ""
      executeAction(script, info)
    end
  end)
end
