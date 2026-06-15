-- KDE Connect — desktop widget.

local daemonAvailable = false
local busctlAvailable = false
local devices = {}
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

function triggerRefresh()
  noctalia.state.set("command", { action = "refresh" })
end

local function render()
  -- Clear previous dynamic callbacks
  for name, _ in clickFuncs do
    _G[name] = nil
  end
  clickFuncs = {}

  local title = noctalia.tr("panel.title") or "Connected Devices"
  local rows = {
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.button({ text = "↻", variant = "flat", onClick = "triggerRefresh" })
    })
  }

  if not busctlAvailable then
    table.insert(rows, ui.label({
      text = noctalia.tr("panel.busctl-error.unavailable-title") or "busctl not found!",
      fontSize = 13,
      color = "error",
      fontWeight = "bold"
    }))
    table.insert(rows, ui.label({
      text = noctalia.tr("panel.busctl-error.unavailable-desc") or "Please install systemd/busctl.",
      fontSize = 11,
      color = "on_surface_variant"
    }))
    desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
    return
  end

  if not daemonAvailable then
    table.insert(rows, ui.label({
      text = noctalia.tr("panel.kdeconnect-error.unavailable-title") or "kdeconnectd is not running!",
      fontSize = 13,
      color = "error",
      fontWeight = "bold"
    }))
    table.insert(rows, ui.label({
      text = noctalia.tr("panel.kdeconnect-error.unavailable-desc") or "Make sure KDE Connect is running.",
      fontSize = 11,
      color = "on_surface_variant"
    }))
    desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
    return
  end

  if #devices == 0 then
    table.insert(rows, ui.label({
      text = noctalia.tr("panel.kdeconnect-error.no-devices") or "No devices running KDE Connect found",
      fontSize = 13,
      color = "on_surface_variant",
      align = "center"
    }))
  else
    for _, dev in devices do
      local devRows = {
        ui.label({ text = dev.name, fontSize = 14, fontWeight = "bold" })
      }

      if dev.reachable then
        local statusParts = {}
        if dev.paired then
          table.insert(statusParts, noctalia.tr("control_center.state.connected") or "Connected")
          if dev.battery >= 0 then
            local chg = if dev.charging then " (Charging)" else ""
            table.insert(statusParts, `🔋 {dev.battery}%{chg}`)
          end
          if dev.cellularNetworkType ~= "" then
            table.insert(statusParts, `📶 {dev.cellularNetworkType}`)
          end
        else
          table.insert(statusParts, noctalia.tr("control_center.state.not-paired") or "Not paired")
        end
        
        table.insert(devRows, ui.label({
          text = table.concat(statusParts, " • "),
          fontSize = 11,
          color = "primary"
        }))

        -- Action buttons
        local btnRow = {}
        if dev.paired then
          -- Dynamic callbacks
          local findName = `find_{dev.id}`
          _G[findName] = function()
            noctalia.state.set("command", { action = "find", deviceId = dev.id })
          end
          clickFuncs[findName] = true

          local browseName = `browse_{dev.id}`
          _G[browseName] = function()
            noctalia.state.set("command", { action = "browse", deviceId = dev.id })
          end
          clickFuncs[browseName] = true

          local pingName = `ping_{dev.id}`
          _G[pingName] = function()
            noctalia.state.set("command", { action = "ping", deviceId = dev.id })
          end
          clickFuncs[pingName] = true

          local shareName = `share_{dev.id}`
          _G[shareName] = function()
            promptFile("Select File to Share", function(path)
              noctalia.state.set("command", { action = "share", deviceId = dev.id, filePath = path })
            end)
          end
          clickFuncs[shareName] = true

          local unpairName = `unpair_{dev.id}`
          _G[unpairName] = function()
            noctalia.state.set("command", { action = "unpair", deviceId = dev.id })
          end
          clickFuncs[unpairName] = true

          table.insert(btnRow, ui.button({ text = "Ring", variant = "outline", onClick = findName }))
          table.insert(btnRow, ui.button({ text = "Files", variant = "outline", onClick = browseName }))
          table.insert(btnRow, ui.button({ text = "Send", variant = "outline", onClick = shareName }))
          table.insert(btnRow, ui.button({ text = "Ping", variant = "outline", onClick = pingName }))
          table.insert(btnRow, ui.button({ text = "Unpair", variant = "flat", onClick = unpairName }))
        else
          local pairName = `pair_{dev.id}`
          _G[pairName] = function()
            noctalia.state.set("command", { action = "pair", deviceId = dev.id })
          end
          clickFuncs[pairName] = true

          table.insert(btnRow, ui.button({ text = "Pair Device", variant = "primary", onClick = pairName }))
        end

        table.insert(devRows, ui.row({ gap = 6 }, btnRow))
      else
        table.insert(devRows, ui.label({
          text = noctalia.tr("control_center.state.disconnected") or "Disconnected",
          fontSize = 11,
          color = "on_surface_variant"
        }))
      end

      table.insert(rows, ui.column({ gap = 4, padding = 8 }, devRows))
    end
  end

  desktopWidget.render(ui.column({ gap = 12, padding = 16 }, rows))
end

noctalia.state.watch("daemonAvailable", function(val)
  daemonAvailable = val == true
  render()
end)

noctalia.state.watch("busctlAvailable", function(val)
  busctlAvailable = val == true
  render()
end)

noctalia.state.watch("devices", function(val)
  devices = if type(val) == "table" then val else {}
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
