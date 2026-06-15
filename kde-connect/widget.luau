-- KDE Connect — bar widget.

local daemonAvailable = false
local anyDevicesConnected = false
local devices = {}

local function render()
  local hideIfDisconnected = barWidget.getConfig("hideIfDisconnected") == true
  
  if not daemonAvailable then
    barWidget.setGlyph("device-mobile-off")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("panel.kdeconnect-error.unavailable-title") or "kdeconnectd is not running")
    barWidget.setVisible(not hideIfDisconnected)
    return
  end

  if #devices == 0 then
    barWidget.setGlyph("device-mobile")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("panel.kdeconnect-error.no-devices") or "No devices found")
    barWidget.setVisible(not hideIfDisconnected)
    return
  end

  barWidget.setGlyph("device-mobile")
  if anyDevicesConnected then
    barWidget.setGlyphColor("primary")
    barWidget.setVisible(true)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setVisible(not hideIfDisconnected)
  end

  -- Tooltip list
  local tooltipLines = {}
  for _, dev in devices do
    local stateStr = "Disconnected"
    if dev.reachable then
      stateStr = if dev.paired then (noctalia.tr("control_center.state.connected") or "Connected") else (noctalia.tr("control_center.state.not-paired") or "Not paired")
    else
      stateStr = noctalia.tr("control_center.state.disconnected") or "Disconnected"
    end
    table.insert(tooltipLines, `{dev.name} ({stateStr})`)
  end
  barWidget.setTooltip(table.concat(tooltipLines, "\n"))
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("daemonAvailable", function(val)
  daemonAvailable = val == true
  render()
end)

noctalia.state.watch("anyDevicesConnected", function(val)
  anyDevicesConnected = val == true
  render()
end)

noctalia.state.watch("devices", function(val)
  devices = if type(val) == "table" then val else {}
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
