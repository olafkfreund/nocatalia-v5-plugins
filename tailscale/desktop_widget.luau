-- Tailscale — desktop widget.

local installed = false
local running = false
local needsLogin = false
local tailscaleIp = ""
local tailscaleStatus = "Disconnected"
local exitNodeStatus = nil
local accounts = {}
local currentAccountId = ""
local peers = {}

local clickFuncs = {}

local function promptFile(title, callback)
  local cmd = `zenity --file-selection --title='{title:gsub("'", "'\\''")}' 2>/dev/null || kdialog --getopenfilename . 2>/dev/null`
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local val = (res.stdout or res.body or ""):gsub("[\r\n]+$", "")
      if val ~= "" then
        callback(val)
      end
    end
  end)
end

local function copyToClipboard(text)
  local escaped = string.gsub(text, "'", "'\\''")
  noctalia.runAsync("printf '%s' '" .. escaped .. "' | wl-copy || printf '%s' '" .. escaped .. "' | xclip -sel clip")
end

function toggleConnection()
  if running then
    noctalia.state.set("command", { action = "disconnect" })
  else
    noctalia.state.set("command", { action = "connect" })
  end
end

function triggerLogin()
  noctalia.state.set("command", { action = "login" })
end

function disableExitNode()
  noctalia.state.set("command", { action = "clear_exit_node" })
end

function triggerReceive()
  local downloadDir = noctalia.getConfig("taildropDownloadDir") or "~/Downloads"
  local receiveMode = noctalia.getConfig("taildropReceiveMode") or "operator"
  noctalia.state.set("command", { action = "taildrop_receive", downloadDir = downloadDir, receiveMode = receiveMode })
end

local function render()
  -- Clear previous dynamic callbacks
  for name, _ in clickFuncs do
    _G[name] = nil
  end
  clickFuncs = {}

  local title = "Tailscale"
  local rows = {
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.label({ text = `({tailscaleStatus})`, fontSize = 11, color = "on_surface_variant" })
    })
  }

  if not installed then
    table.insert(rows, ui.label({ text = "Tailscale is not installed or not in PATH", fontSize = 12, color = "error" }))
    desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
    return
  end

  -- Action buttons
  local topActions = {
    ui.button({
      text = if running then "Disconnect" else "Connect",
      variant = "primary",
      onClick = "toggleConnection"
    })
  }

  if needsLogin then
    table.insert(topActions, ui.button({
      text = "Login",
      variant = "primary",
      onClick = "triggerLogin"
    }))
  end

  if running and (noctalia.getConfig("taildropEnabled") ~= false) then
    table.insert(topActions, ui.button({
      text = "Receive Files",
      variant = "outline",
      onClick = "triggerReceive"
    }))
  end

  table.insert(rows, ui.row({ gap = 8 }, topActions))

  if running and tailscaleIp ~= "" then
    table.insert(rows, ui.label({ text = `IP: {tailscaleIp}`, fontSize = 12, color = "on_surface_variant" }))
  end

  -- Switch accounts
  if #accounts > 1 then
    table.insert(rows, ui.label({ text = "Switch Account:", fontSize = 11, fontWeight = "semibold", color = "primary" }))
    local accButtons = {}
    for _, acc in ipairs(accounts) do
      local accId = acc.id
      local cbName = `switch_acc_{accId}`
      _G[cbName] = function()
        noctalia.state.set("command", { action = "switch_account", id = accId })
      end
      clickFuncs[cbName] = true

      local isSelected = accId == currentAccountId
      local displayName = acc.tailnet or acc.account or acc.nickname or accId
      table.insert(accButtons, ui.button({
        text = displayName,
        variant = if isSelected then "primary" else "outline",
        onClick = cbName
      }))
    end
    table.insert(rows, ui.row({ gap = 6 }, accButtons))
  end

  -- Exit node active status
  if exitNodeStatus then
    local exitNodeIp = ""
    if exitNodeStatus.TailscaleIPs and #exitNodeStatus.TailscaleIPs > 0 then
      exitNodeIp = exitNodeStatus.TailscaleIPs[1]
    end
    local onlineStr = if exitNodeStatus.Online then "Online" else "Offline"
    table.insert(rows, ui.column({ gap = 4, padding = 6 }, {
      ui.label({ text = `Exit Node Active: {exitNodeIp} ({onlineStr})`, fontSize = 12, color = "primary", fontWeight = "semibold" }),
      ui.button({ text = "Disable Exit Node", variant = "outline", onClick = "disableExitNode" })
    }))
  end

  -- Peers list
  if running and #peers > 0 then
    table.insert(rows, ui.label({ text = "Peers:", fontSize = 13, fontWeight = "bold", color = "primary" }))

    -- Settings for actions
    local termCmd = noctalia.getConfig("terminalCommand") or ""
    local sshUser = noctalia.getConfig("sshUsername") or ""
    local pingCount = tonumber(noctalia.getConfig("pingCount")) or 5
    local taildropEnabled = noctalia.getConfig("taildropEnabled") ~= false

    for _, peer in ipairs(peers) do
      local peerIp = peer.TailscaleIPs[1] or ""
      local peerHostname = peer.HostName or ""
      local dnsName = peer.DNSName or ""
      local isOnline = peer.Online == true

      local peerRows = {
        ui.row({ gap = 8, align = "center" }, {
          ui.label({ text = peerHostname, fontSize = 13, fontWeight = "bold" }),
          ui.label({ text = if isOnline then "● Online" else "○ Offline", fontSize = 11, color = if isOnline then "success" else "on_surface_variant" })
        })
      }

      if peerIp ~= "" then
        table.insert(peerRows, ui.label({ text = peerIp, fontSize = 11, color = "on_surface_variant" }))
      end

      if isOnline and peerIp ~= "" then
        local peerActions = {}

        -- Copy IP callback
        local copyIpCb = `copy_ip_{peerIp:gsub("%.", "_")}`
        _G[copyIpCb] = function()
          copyToClipboard(peerIp)
          noctalia.notify("Tailscale", `IP {peerIp} copied to clipboard`)
        end
        clickFuncs[copyIpCb] = true
        table.insert(peerActions, ui.button({ text = "Copy", variant = "outline", onClick = copyIpCb }))

        -- SSH callback
        if termCmd ~= "" then
          local sshCb = `ssh_{peerIp:gsub("%.", "_")}`
          _G[sshCb] = function()
            local target = peerIp
            if sshUser ~= "" then
              target = `{sshUser}@{peerIp}`
            end
            noctalia.runAsync(`{termCmd} -e ssh {target}`)
          end
          clickFuncs[sshCb] = true
          table.insert(peerActions, ui.button({ text = "SSH", variant = "outline", onClick = sshCb }))

          -- Ping callback
          local pingCb = `ping_{peerIp:gsub("%.", "_")}`
          _G[pingCb] = function()
            noctalia.runAsync(`{termCmd} -e ping -c {pingCount} {peerIp}`)
          end
          clickFuncs[pingCb] = true
          table.insert(peerActions, ui.button({ text = "Ping", variant = "outline", onClick = pingCb }))
        end

        -- Taildrop Send callback
        if taildropEnabled then
          local taildropCb = `taildrop_send_{peerIp:gsub("%.", "_")}`
          _G[taildropCb] = function()
            promptFile("Select file to send", function(filePath)
              -- Extract tailscale name
              local tsName = string.match(dnsName, "^([^%.]+)") or peerIp
              local target = tsName .. ":"
              noctalia.state.set("command", { action = "taildrop_send", files = { filePath }, target = target })
            end)
          end
          clickFuncs[taildropCb] = true
          table.insert(peerActions, ui.button({ text = "Send", variant = "outline", onClick = taildropCb }))
        end

        -- Exit node options
        if peer.ExitNodeOption and not peer.ExitNode then
          local exitNodeCb = `exitnode_{peerIp:gsub("%.", "_")}`
          _G[exitNodeCb] = function()
            noctalia.state.set("command", { action = "set_exit_node", ip = peerIp })
          end
          clickFuncs[exitNodeCb] = true
          table.insert(peerActions, ui.button({ text = "Use Exit Node", variant = "outline", onClick = exitNodeCb }))
        end

        table.insert(peerRows, ui.row({ gap = 4 }, peerActions))
      end

      table.insert(rows, ui.column({ gap = 4, padding = 6 }, peerRows))
    end
  end

  desktopWidget.render(ui.column({ gap = 12, padding = 16 }, rows))
end

noctalia.state.watch("installed", function(val)
  installed = val == true
  render()
end)

noctalia.state.watch("running", function(val)
  running = val == true
  render()
end)

noctalia.state.watch("needsLogin", function(val)
  needsLogin = val == true
  render()
end)

noctalia.state.watch("tailscaleIp", function(val)
  tailscaleIp = tostring(val or "")
  render()
end)

noctalia.state.watch("tailscaleStatus", function(val)
  tailscaleStatus = tostring(val or "Disconnected")
  render()
end)

noctalia.state.watch("exitNodeStatus", function(val)
  exitNodeStatus = if type(val) == "table" then val else nil
  render()
end)

noctalia.state.watch("accounts", function(val)
  accounts = if type(val) == "table" then val else {}
  render()
end)

noctalia.state.watch("currentAccountId", function(val)
  currentAccountId = tostring(val or "")
  render()
end)

noctalia.state.watch("peers", function(val)
  peers = if type(val) == "table" then val else {}
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
