-- Battery & Power Management — background service.

noctalia.setUpdateInterval(2000) -- Check every 2 seconds

local lastFileContent = ""
local currentProfile = "balanced"
local batteryThreshold = 80
local batPercent = 0
local wattNum = 0.0
local batStatus = "Unknown"
local timeRemaining = "..."

local function parseEta(out)
  if not out then return "..." end
  for line in out:gmatch("[^\r\n]+") do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed:find("time to empty:") == 1 or trimmed:find("time to full:") == 1 then
      local value = trimmed:match(":%s*(.*)$")
      if value then
        local numStr, unit = value:match("(%d+%.?%d*)%s*(%S+)")
        local num = tonumber(numStr)
        if num then
          local minutes = 0
          if unit:find("hour") == 1 then
            minutes = num * 60
          elseif unit:find("minute") == 1 then
            minutes = num
          elseif unit:find("second") == 1 then
            minutes = num / 60
          elseif unit:find("day") == 1 then
            minutes = num * 1440
          else
            return value
          end
          local total = math.round(minutes)
          local h = math.floor(total / 60)
          local m = total % 60
          if h > 0 then
            return `{h}h {m}m`
          else
            return `{m}m`
          end
        end
        return value
      end
    end
  end
  return "..."
end

local function checkBattery()
  local devPath = noctalia.getConfig("batteryDevice") or "/sys/class/power_supply/BAT0"
  local dev = devPath:match("[^/]+$") or "BAT0"

  -- 1. Read battery threshold
  noctalia.runAsync(`cat '{devPath}/charge_control_end_threshold' 2>/dev/null`, function(res)
    if res.exitCode == 0 then
      local val = tonumber(res.stdout:gsub("%s+", ""))
      if val and val >= 50 and val <= 100 then
        batteryThreshold = val
        noctalia.state.set("batteryThreshold", val)
      end
    end
  end)

  -- 2. Read uevent file
  noctalia.runAsync(`cat '{devPath}/uevent' 2>/dev/null`, function(res)
    if res.exitCode == 0 then
      local content = res.stdout
      local cap = 0
      local rate = 0
      local statusRaw = "Unknown"

      for line in content:gmatch("[^\r\n]+") do
        local key, val = line:match("^POWER_SUPPLY_([^=]+)=(.*)$")
        if key == "CAPACITY" then
          cap = tonumber(val) or 0
        elseif key == "POWER_NOW" then
          rate = tonumber(val) or 0
        elseif key == "STATUS" then
          statusRaw = val
        end
      end

      batPercent = cap
      batStatus = statusRaw
      wattNum = rate / 1000000.0

      noctalia.state.set("batPercent", batPercent)
      noctalia.state.set("batStatus", batStatus)
      noctalia.state.set("wattNum", wattNum)
    end
  end)

  -- 3. Get time remaining from upower
  noctalia.runAsync(`upower -i /org/freedesktop/UPower/devices/battery_{dev} 2>/dev/null`, function(res)
    if res.exitCode == 0 then
      timeRemaining = parseEta(res.stdout)
    else
      timeRemaining = "..."
    end
    noctalia.state.set("timeRemaining", timeRemaining)
  end)

  -- 4. Get current power profile
  noctalia.runAsync("powerprofilesctl get", function(res)
    if res.exitCode == 0 then
      currentProfile = res.stdout:gsub("%s+", "")
      noctalia.state.set("currentProfile", currentProfile)
    end
  end)
end

-- Watch for commands
noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  local devPath = noctalia.getConfig("batteryDevice") or "/sys/class/power_supply/BAT0"

  if cmd.action == "set_profile" then
    noctalia.runAsync(`powerprofilesctl set {cmd.value}`, function()
      checkBattery()
    end)
  elseif cmd.action == "set_threshold" then
    local val = tonumber(cmd.value)
    if val and val >= 50 and val <= 100 then
      noctalia.runAsync(`sh -c "echo {val} > {devPath}/charge_control_end_threshold"`, function()
        checkBattery()
      end)
    end
  elseif cmd.action == "refresh" then
    checkBattery()
  end
end)

function update()
  checkBattery()
end
