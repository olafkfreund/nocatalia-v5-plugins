-- KDE Connect — background service.
-- Periodically queries org.kde.kdeconnect over DBus and processes commands.

noctalia.setUpdateInterval(5000) -- Check daemon every 5 seconds

local resolvedScriptPath = ""
local pathDetected = false
local queryPending = false

local function detectPath(callback)
  local home = noctalia.getenv("HOME") or "/tmp"
  local testPaths = {
    "kde-connect/query_devices.py",
    `{home}/.local/share/noctalia/plugins/kde-connect/query_devices.py`,
    `{home}/.local/share/noctalia/plugins/kde-connect-master/query_devices.py`
  }
  
  local function tryIdx(idx)
    if idx > #testPaths then
      resolvedScriptPath = "query_devices.py"
      callback()
      return
    end
    local p = testPaths[idx]
    noctalia.runAsync(`test -f '{p}'`, function(res)
      if res.exitCode == 0 then
        resolvedScriptPath = p
        callback()
      else
        tryIdx(idx + 1)
      end
    end)
  end
  tryIdx(1)
end

local function refreshStatus()
  if not pathDetected or queryPending then return end
  queryPending = true
  
  noctalia.runAsync(`python3 '{resolvedScriptPath}'`, function(res)
    queryPending = false
    if res.exitCode == 0 then
      local success, data = pcall(noctalia.json.decode, res.stdout or res.body)
      if success and type(data) == "table" then
        noctalia.state.set("daemonAvailable", data.available == true)
        noctalia.state.set("busctlAvailable", data.busctl_available == true)
        noctalia.state.set("devices", data.devices or {})
        
        -- Check if any device is connected/reachable
        local anyConnected = false
        if type(data.devices) == "table" then
          for _, dev in data.devices do
            if dev.reachable then
              anyConnected = true
              break
            end
          end
        end
        noctalia.state.set("anyDevicesConnected", anyConnected)
      end
    end
  end)
end

detectPath(function()
  pathDetected = true
  refreshStatus()
end)

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  
  local action = cmd.action
  local deviceId = cmd.deviceId
  
  if action == "find" then
    local dbusCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId}/findmyphone org.kde.kdeconnect.device.findmyphone ring`
    noctalia.runAsync(dbusCmd)
    
  elseif action == "pair" then
    local dbusCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId} org.kde.kdeconnect.device requestPairing`
    noctalia.runAsync(dbusCmd, function()
      refreshStatus()
    end)
    
  elseif action == "unpair" then
    local dbusCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId} org.kde.kdeconnect.device unpair`
    noctalia.runAsync(dbusCmd, function()
      refreshStatus()
    end)
    
  elseif action == "ping" then
    local dbusCmd = "busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/" .. deviceId .. "/remotecontrol org.kde.kdeconnect.device.remotecontrol sendCommand \"a{sv}\" \"1\" \"singleclick\" \"b\" \"true\""
    noctalia.runAsync(dbusCmd, function()
      refreshStatus()
    end)
    
  elseif action == "share" then
    local filePath = cmd.filePath
    if filePath and filePath ~= "" then
      local dbusCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId}/share org.kde.kdeconnect.device.share shareUrl s "file://{filePath}"`
      noctalia.runAsync(dbusCmd)
    end
    
  elseif action == "browse" then
    local dbusCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId}/sftp org.kde.kdeconnect.device.sftp mountAndWait`
    noctalia.runAsync(dbusCmd, function(mountRes)
      if mountRes.exitCode == 0 then
        local getDirsCmd = `busctl --user call org.kde.kdeconnect /modules/kdeconnect/devices/{deviceId}/sftp org.kde.kdeconnect.device.sftp getDirectories`
        noctalia.runAsync(getDirsCmd, function(dirsRes)
          if dirsRes.exitCode == 0 then
            local success, dirsData = pcall(noctalia.json.decode, dirsRes.stdout or dirsRes.body)
            if success and type(dirsData) == "table" and type(dirsData.data) == "table" then
              -- Parse directories and open xdg-open on first path
              local firstData = dirsData.data[1]
              if type(firstData) == "table" then
                -- Get first key
                local path = nil
                for k, _ in firstData do
                  path = k
                  break
                end
                if path then
                  noctalia.runAsync(`xdg-open 'file://{path}'`)
                end
              end
            end
          end
        end)
      end
    end)
    
  elseif action == "refresh" then
    refreshStatus()
  end
end)

function update()
  refreshStatus()
end
