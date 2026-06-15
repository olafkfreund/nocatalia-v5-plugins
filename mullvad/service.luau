-- Mullvad VPN — background service.
-- Queries Mullvad status and handles connection, lockdown, and relay configurations.

noctalia.setUpdateInterval(3000) -- Refresh status every 3 seconds

local resolvedScriptPath = ""
local pathDetected = false
local queryPending = false
local listLoaded = false

local function detectPath(callback)
  local home = noctalia.getenv("HOME") or "/tmp"
  local testPaths = {
    "mullvad/query_mullvad.py",
    `{home}/.local/share/noctalia/plugins/mullvad/query_mullvad.py`,
    `{home}/.local/share/noctalia/plugins/mullvad-master/query_mullvad.py`
  }
  
  local function tryIdx(idx)
    if idx > #testPaths then
      resolvedScriptPath = "query_mullvad.py"
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

local function refreshStatus(loadRelays)
  if not pathDetected or queryPending then return end
  queryPending = true
  
  local args = if loadRelays then "--list-relays" else ""
  noctalia.runAsync(`python3 '{resolvedScriptPath}' {args}`, function(res)
    queryPending = false
    if res.exitCode == 0 then
      local success, data = pcall(noctalia.json.decode, res.stdout or res.body)
      if success and type(data) == "table" then
        noctalia.state.set("installed", data.installed == true)
        if not data.installed then return end
        
        noctalia.state.set("vpn_state", data.state or "disconnected")
        noctalia.state.set("locked", data.locked == true)
        noctalia.state.set("current_location", data.current_location)
        noctalia.state.set("visible_location", data.visible_location)
        noctalia.state.set("lockdown", data.lockdown == true)
        noctalia.state.set("autoconnect", data.autoconnect == true)
        noctalia.state.set("lan", data.lan or "allow")
        noctalia.state.set("relay_selection", data.relay_selection)
        noctalia.state.set("multihop", data.multihop == true)
        noctalia.state.set("multihop_entry", data.multihop_entry or "")
        noctalia.state.set("ip_version", data.ip_version or "any")
        noctalia.state.set("days_left", tonumber(data.days_left) or 9999)
        
        if loadRelays and type(data.relay_list) == "table" then
          noctalia.state.set("relay_list", data.relay_list)
          listLoaded = true
        end
      end
    end
  end)
end

detectPath(function()
  pathDetected = true
  refreshStatus(true)
end)

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  
  local action = cmd.action
  
  if action == "connect" then
    noctalia.runAsync("mullvad connect", function(res)
      if res.exitCode == 0 then
        noctalia.notify("Mullvad VPN", noctalia.tr("toast.connected") or "Connected")
      else
        noctalia.notifyError("Mullvad VPN", noctalia.tr("toast.connect-failed") or "Connection failed")
      end
      refreshStatus()
    end)
    
  elseif action == "disconnect" then
    noctalia.runAsync("mullvad disconnect", function(res)
      if res.exitCode == 0 then
        noctalia.notify("Mullvad VPN", noctalia.tr("toast.disconnected") or "Disconnected")
      end
      refreshStatus()
    end)
    
  elseif action == "reconnect" then
    noctalia.runAsync("mullvad reconnect", function()
      refreshStatus()
    end)
    
  elseif action == "toggle_lockdown" then
    local on = cmd.on == true
    noctalia.runAsync(`mullvad lockdown-mode set {if on then "on" else "off"}`, function()
      refreshStatus()
    end)
    
  elseif action == "toggle_autoconnect" then
    local on = cmd.on == true
    noctalia.runAsync(`mullvad auto-connect set {if on then "on" else "off"}`, function()
      refreshStatus()
    end)
    
  elseif action == "toggle_lan" then
    local allow = cmd.allow == true
    noctalia.runAsync(`mullvad lan set {if allow then "allow" else "block"}`, function()
      refreshStatus()
    end)
    
  elseif action == "set_location" then
    local country = cmd.country
    local city = cmd.city
    local host = cmd.hostname
    
    local args = { "mullvad", "relay", "set", "location" }
    if country and country ~= "" then
      table.insert(args, country)
      if city and city ~= "" then
        table.insert(args, city)
        if host and host ~= "" then
          table.insert(args, host)
        end
      end
    else
      table.insert(args, "any")
    end
    
    noctalia.runAsync(table.concat(args, " "), function()
      refreshStatus()
      if noctalia.getConfig("relayClickConnects") ~= false then
        noctalia.runAsync("mullvad connect")
      end
    end)
    
  elseif action == "set_multihop" then
    local on = cmd.on == true
    noctalia.runAsync(`mullvad relay set multihop {if on then "on" else "off"}`, function()
      refreshStatus()
    end)
    
  elseif action == "set_ip_version" then
    local v = cmd.version or "any"
    noctalia.runAsync(`mullvad relay set ip-version {v}`, function()
      refreshStatus()
    end)
    
  elseif action == "refresh" then
    refreshStatus(not listLoaded)
  end
end)

function update()
  refreshStatus(not listLoaded)
end
