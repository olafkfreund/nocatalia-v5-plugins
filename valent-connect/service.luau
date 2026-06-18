-- Valent Connect — background service.
-- Checks Valent device connection status via D-Bus.

local deviceName = ""
local deviceId = ""
local connected = false
local batteryLevel = -1
local valentAvailable = false

local function updateState()
  noctalia.state.set("deviceName", deviceName)
  noctalia.state.set("connected", connected)
  noctalia.state.set("batteryLevel", batteryLevel)
  noctalia.state.set("valentAvailable", valentAvailable)
end

local function refresh()
  -- Check if Valent is running
  noctalia.runAsync("dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | grep -q 'ca.andyholmes.Valent' && echo 'yes'", function(res)
    if res.exitCode ~= 0 or not (res.stdout or res.body or ""):match("yes") then
      valentAvailable = false
      connected = false
      updateState()
      return
    end
    valentAvailable = true

    -- Try to get devices via gdbus
    local targetId = noctalia.getConfig("mainDeviceId") or ""
    local cmd = "gdbus call --session --dest ca.andyholmes.Valent --object-path /ca/andyholmes/Valent --method ca.andyholmes.Valent.ListDevices 2>/dev/null"
    noctalia.runAsync(cmd, function(devRes)
      if devRes.exitCode ~= 0 then
        connected = false
        updateState()
        return
      end
      local text = devRes.stdout or devRes.body or ""
      -- Parse device IDs from result
      local ids = {}
      for id in text:gmatch("'([^']+)'") do
        ids[#ids + 1] = id
      end
      if #ids == 0 then
        connected = false
        updateState()
        return
      end
      -- Use first device or targeted device
      local useId = ids[1]
      if targetId ~= "" then
        for _, id in ipairs(ids) do
          if id == targetId then useId = id; break end
        end
      end
      deviceId = useId
      connected = true
      -- Try to get device name
      noctalia.runAsync("gdbus get-property --session --dest ca.andyholmes.Valent --object-path /ca/andyholmes/Valent/Device/" .. useId:gsub("[^%w]", "_") .. " ca.andyholmes.Valent.Device Name 2>/dev/null", function(nameRes)
        if nameRes.exitCode == 0 then
          local name = (nameRes.stdout or nameRes.body or ""):match("'([^']+)'")
          deviceName = name or useId
        end
        updateState()
      end)
    end)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  end
end)

refresh()

noctalia.setUpdateInterval(10000)

function onUpdate()
  refresh()
end
