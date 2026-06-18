-- ProtonVPN — bar widget.

local vpnStatus = "unknown"
local serverName = ""
local isLoading = true

local function render()
  local connectedColor = barWidget.getConfig("connectedColor") or "primary"

  if isLoading then
    barWidget.setGlyph("reload")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("status.loading") or "Loading...")
    return
  end

  if vpnStatus == "connected" then
    barWidget.setGlyph("shield-lock")
    if connectedColor == "none" then
      barWidget.setGlyphColor("on_surface")
    else
      barWidget.setGlyphColor(connectedColor)
    end
    local display = serverName ~= "" and serverName or "VPN"
    barWidget.setText(display)
    barWidget.setTooltip(noctalia.tr("status.connected") or ("Connected: " .. display))
  elseif vpnStatus == "disconnected" then
    local disconnectedColor = barWidget.getConfig("disconnectedColor") or "on_surface_variant"
    barWidget.setGlyph("shield")
    if disconnectedColor == "none" then
      barWidget.setGlyphColor("on_surface_variant")
    else
      barWidget.setGlyphColor(disconnectedColor)
    end
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("status.disconnected") or "Disconnected")
  else
    barWidget.setGlyph("shield")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("status.unknown") or "Status unknown")
  end
end

function onClick()
  if vpnStatus == "connected" then
    noctalia.state.set("command", "disconnect")
  else
    noctalia.state.set("command", "connect")
  end
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("vpnStatus", function(val)
  vpnStatus = val or "unknown"
  render()
end)

noctalia.state.watch("serverName", function(val)
  serverName = val or ""
  render()
end)

noctalia.state.watch("isLoading", function(val)
  isLoading = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
