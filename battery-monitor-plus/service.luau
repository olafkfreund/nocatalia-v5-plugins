-- Battery Monitor Plus — background service.

noctalia.setUpdateInterval(1000)

local lastCheckTime = 0
local scriptPath = nil
local checkedPath = false
local currentProfile = "balanced"

local function getScriptPaths()
  local home = os.getenv("HOME") or "/tmp"
  return {
    "battery-monitor-plus/scripts/read_battery_sysfs.sh",
    `{home}/.local/share/noctalia/plugins/battery-monitor-plus/scripts/read_battery_sysfs.sh`,
    `{home}/.local/share/noctalia/plugins/battery-monitor-plus-master/scripts/read_battery_sysfs.sh`
  }
end

local function runScan(path, devicePath)
  noctalia.runAsync(`sh '{path}' '{devicePath}'`, function(res)
    if res.exitCode == 0 then
      local ok, parsed = pcall(noctalia.json.decode, res.stdout or res.body)
      if ok and type(parsed) == "table" then
        noctalia.state.set("ok", parsed.ok == true)
        noctalia.state.set("status", parsed.status or "Unknown")
        noctalia.state.set("powerWatts", tonumber(parsed.powerWatts) or -1.0)
        noctalia.state.set("timeToEmpty", tonumber(parsed.timeToEmpty) or 0)
        noctalia.state.set("timeToFull", tonumber(parsed.timeToFull) or 0)
        noctalia.state.set("capacity", tonumber(parsed.capacity) or -1)
        noctalia.state.set("health", tonumber(parsed.healthPercent) or 100)
        noctalia.state.set("error", parsed.error or "")
      end
    end
  end)

  -- Get current power profile
  noctalia.runAsync("powerprofilesctl get 2>/dev/null", function(res)
    if res.exitCode == 0 then
      currentProfile = res.stdout:gsub("%s+", "")
      noctalia.state.set("currentProfile", currentProfile)
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  if cmd.action == "set_profile" then
    noctalia.runAsync(`powerprofilesctl set {cmd.value}`, function()
      local devPath = noctalia.getConfig("deviceNativePath") or "__default__"
      if scriptPath then runScan(scriptPath, devPath) end
    end)
  elseif cmd.action == "refresh" then
    local devPath = noctalia.getConfig("deviceNativePath") or "__default__"
    if scriptPath then runScan(scriptPath, devPath) end
  end
end)

function update()
  local devPath = noctalia.getConfig("deviceNativePath") or "__default__"
  local interval = noctalia.getConfig("refreshIntervalSeconds") or 5

  if not checkedPath then
    checkedPath = true
    local paths = getScriptPaths()
    local function tryFind(idx)
      if idx > #paths then
        noctalia.log("BatteryMonitorPlus: read_battery_sysfs.sh not found")
        return
      end
      local p = paths[idx]
      noctalia.runAsync(`test -f '{p}'`, function(res)
        if res.exitCode == 0 then
          scriptPath = p
          runScan(scriptPath, devPath)
          lastCheckTime = os.clock()
        else
          tryFind(idx + 1)
        end
      end)
    end
    tryFind(1)
    return
  end

  local now = os.clock()
  if scriptPath and (now - lastCheckTime >= interval) then
    lastCheckTime = now
    runScan(scriptPath, devPath)
  end
end
