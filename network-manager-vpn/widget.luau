-- Network Manager VPN — bar widget.

local connected = false
local activeVpn = ""
local connectionCount = 0

local function render()
  local connectedColor = barWidget.getConfig("connectedColor") or "primary"
  local disconnectedColor = barWidget.getConfig("disconnectedColor") or "none"

  barWidget.setGlyph("shield")

  if connected then
    if connectedColor ~= "none" then
      barWidget.setGlyphColor(connectedColor)
    else
      barWidget.setGlyphColor("on_surface")
    end
    local display = activeVpn ~= "" and activeVpn or "VPN"
    barWidget.setText(display)
    barWidget.setTooltip("VPN: " .. display .. " (connected) — click to disconnect")
  else
    if disconnectedColor ~= "none" then
      barWidget.setGlyphColor(disconnectedColor)
    else
      barWidget.setGlyphColor("on_surface_variant")
    end
    barWidget.setText("")
    if connectionCount > 0 then
      barWidget.setTooltip("VPN: Disconnected | " .. connectionCount .. " profile(s) — click to connect")
    else
      barWidget.setTooltip("VPN: No profiles configured")
    end
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("activeVpn", function(val)
  activeVpn = val or ""
  render()
end)

noctalia.state.watch("connectionCount", function(val)
  connectionCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
