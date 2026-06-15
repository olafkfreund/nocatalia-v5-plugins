-- Tailscale — background service.

noctalia.setUpdateInterval(5000)

local resolvedScriptPath = ""
local pathDetected = false
local queryPending = false

local function detectPath(callback)
  local home = noctalia.getenv("HOME") or "/tmp"
  local testPaths = {
    "tailscale/query_tailscale.py",
    `{home}/.local/share/noctalia/plugins/tailscale/query_tailscale.py`,
    `{home}/.local/share/noctalia/plugins/tailscale-master/query_tailscale.py`
  }
  
  local function tryIdx(idx)
    if idx > #testPaths then
      resolvedScriptPath = "query_tailscale.py"
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
        noctalia.state.set("installed", data.installed == true)
        if not data.installed then return end
        
        noctalia.state.set("running", data.running == true)
        noctalia.state.set("needsLogin", data.needsLogin == true)
        noctalia.state.set("backendState", data.backendState or "Disconnected")
        noctalia.state.set("authUrl", data.authUrl or "")
        noctalia.state.set("tailscaleIp", data.tailscaleIp or "")
        noctalia.state.set("tailscaleStatus", data.tailscaleStatus or "Disconnected")
        noctalia.state.set("peerCount", data.peerCount or 0)
        noctalia.state.set("peers", data.peers or {})
        noctalia.state.set("exitNodeStatus", data.exitNodeStatus)
        noctalia.state.set("accounts", data.accounts or {})
        noctalia.state.set("currentAccountId", data.currentAccountId or "")
      end
    end
  end)
end

detectPath(function()
  pathDetected = true
  refreshStatus()
end)

function update()
  refreshStatus()
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  local action = cmd.action
  
  if action == "connect" then
    noctalia.runAsync("tailscale up", function(res)
      if res.exitCode == 0 then
        noctalia.notify("Tailscale", "Connected")
      else
        noctalia.notifyError("Tailscale", "Connection failed")
      end
      refreshStatus()
    end)
    
  elseif action == "disconnect" then
    noctalia.runAsync("tailscale down", function(res)
      if res.exitCode == 0 then
        noctalia.notify("Tailscale", "Disconnected")
      end
      refreshStatus()
    end)
    
  elseif action == "switch_account" then
    local id = cmd.id
    if id and id ~= "" then
      noctalia.runAsync(`tailscale switch '{id}'`, function(res)
        if res.exitCode == 0 then
          noctalia.notify("Tailscale", "Switched account")
        else
          noctalia.notifyError("Tailscale", "Failed to switch account")
        end
        refreshStatus()
      end)
    end
    
  elseif action == "set_exit_node" then
    local ip = cmd.ip
    if ip and ip ~= "" then
      noctalia.runAsync(`tailscale set --exit-node='{ip}'`, function(res)
        if res.exitCode == 0 then
          noctalia.notify("Tailscale", "Exit node activated")
        else
          noctalia.notifyError("Tailscale", "Failed to set exit node")
        end
        refreshStatus()
      end)
    end
    
  elseif action == "clear_exit_node" then
    noctalia.runAsync("tailscale set --exit-node=", function(res)
      if res.exitCode == 0 then
        noctalia.notify("Tailscale", "Exit node disabled")
      end
      refreshStatus()
    end)
    
  elseif action == "login" then
    local loginServer = noctalia.getConfig("loginServer") or ""
    local cmdStr = "tailscale up --accept-routes --force-reauth"
    if loginServer ~= "" then
      cmdStr = cmdStr .. " --login-server=" .. loginServer
    end
    
    noctalia.runAsync(cmdStr, function(res)
      local output = (res.stdout or "") .. "\n" .. (res.stderr or "")
      local url = string.match(output, "https?://%S+")
      if url then
        noctalia.runAsync("xdg-open " .. url)
        noctalia.notify("Tailscale", "Authentication page opened in browser")
      else
        noctalia.notifyError("Tailscale", "Failed to start login flow")
      end
      refreshStatus()
    end)
    
  elseif action == "taildrop_receive" then
    local downloadDir = cmd.downloadDir or "~/Downloads"
    local receiveMode = cmd.receiveMode or "operator"
    
    local home = noctalia.getenv("HOME") or "/home"
    local actualDir = string.gsub(downloadDir, "^~", home)
    
    noctalia.runAsync(`ls -1 '{actualDir}'`, function(preRes)
      local preFiles = {}
      if preRes.exitCode == 0 then
        for line in string.gmatch(preRes.stdout or "", "[^\r\n]+") do
          preFiles[line] = true
        end
      end
      
      local fileGetCmd = if receiveMode == "pkexec" then `pkexec tailscale file get '{actualDir}'` else `tailscale file get '{actualDir}'`
      noctalia.runAsync(fileGetCmd, function(getRes)
        if getRes.exitCode == 0 then
          noctalia.runAsync(`ls -1 '{actualDir}'`, function(postRes)
            local newFiles = {}
            if postRes.exitCode == 0 then
              for line in string.gmatch(postRes.stdout or "", "[^\r\n]+") do
                if not preFiles[line] then
                  table.insert(newFiles, line)
                end
              end
            end
            if #newFiles > 0 then
              noctalia.notify("Tailscale", "Received files:\n" .. table.concat(newFiles, "\n"))
            else
              noctalia.notify("Tailscale", "No files received")
            end
            refreshStatus()
          end)
        else
          noctalia.notifyError("Tailscale", "Taildrop receive failed")
          refreshStatus()
        end
      end)
    end)
    
  elseif action == "taildrop_send" then
    local filePaths = cmd.files
    local target = cmd.target
    if filePaths and #filePaths > 0 and target and target ~= "" then
      local cpCmd = { "tailscale", "file", "cp" }
      for _, f in ipairs(filePaths) do
        table.insert(cpCmd, f)
      end
      table.insert(cpCmd, target)
      
      local joinedCmd = table.concat(cpCmd, " ")
      noctalia.runAsync(joinedCmd, function(res)
        if res.exitCode == 0 then
          noctalia.notify("Tailscale", "Files sent successfully")
        else
          noctalia.notifyError("Tailscale", "Taildrop send failed: " .. (res.stderr or "unknown error"))
        end
        refreshStatus()
      end)
    end
  end
end)
