-- Battery Threshold — background service.

noctalia.setUpdateInterval(5000) -- Check hardware state every 5 seconds

local currentThreshold = -1
local isAvailable = false
local isWritable = false
local thresholdFile = nil
local initialized = false

local function getThresholdFile()
  local dev = noctalia.getConfig("batteryDevice") or "/sys/class/power_supply/BAT0"
  return `{dev}/charge_control_end_threshold`
end

local function checkStatus(onDone)
  local path = getThresholdFile()
  thresholdFile = path

  noctalia.runAsync(`test -f '{path}'`, function(res)
    if res.exitCode == 0 then
      isAvailable = true
      noctalia.state.set("isAvailable", true)

      -- Check if writable
      noctalia.runAsync(`test -w '{path}'`, function(wRes)
        isWritable = (wRes.exitCode == 0)
        noctalia.state.set("isWritable", isWritable)

        -- Read current value
        noctalia.runAsync(`cat '{path}'`, function(catRes)
          if catRes.exitCode == 0 then
            local val = tonumber(catRes.stdout:gsub("%s+", ""))
            if val then
              currentThreshold = val
              noctalia.state.set("currentThreshold", val)
            end
          end
          if onDone then onDone() end
        end)
      end)
    else
      isAvailable = false
      isWritable = false
      noctalia.state.set("isAvailable", false)
      noctalia.state.set("isWritable", false)
      if onDone then onDone() end
    end
  end)
end

local function setThreshold(val)
  local path = getThresholdFile()
  noctalia.runAsync(`sh -c "echo {val} > '{path}'"`, function(res)
    if res.exitCode == 0 then
      currentThreshold = val
      noctalia.state.set("currentThreshold", val)
    else
      noctalia.log(`BatteryThreshold Error: Failed to write threshold. Exit code: {res.exitCode}`)
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  if cmd.action == "set_threshold" then
    local val = tonumber(cmd.value)
    if val and val >= 40 and val <= 100 then
      setThreshold(val)
    end
  end
end)

function update()
  checkStatus(function()
    if not initialized then
      initialized = true
      -- Restore saved threshold if possible
      local saved = noctalia.getConfig("chargeThreshold") or 80
      if isAvailable and isWritable and currentThreshold ~= saved then
        setThreshold(saved)
      end
    end
  end)
end
