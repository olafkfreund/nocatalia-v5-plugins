-- Tailscale — bar widget.

local installed = false
local running = false
local needsLogin = false
local tailscaleIp = ""
local peerCount = 0
local tailscaleStatus = "Disconnected"

local function render()
  if not installed then
    barWidget.setGlyph("shield-x")
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip("Tailscale is not installed")
    return
  end

  if needsLogin then
    barWidget.setGlyph("shield-lock")
    barWidget.setGlyphColor("primary")
    barWidget.setText("")
    barWidget.setTooltip("Tailscale: Authentication required\nClick to toggle control panel")
    return
  end

  local glyph = "shield"
  local color = "on_surface_variant"
  
  if running then
    glyph = "shield"
    color = barWidget.getConfig("iconColor") or "primary"
  else
    glyph = "shield-off"
    color = "on_surface_variant"
  end

  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(color)

  local textParts = {}
  local tooltipLines = { `Status: {tailscaleStatus}` }

  if running then
    local compact = barWidget.getConfig("compactMode") == true
    local showIp = barWidget.getConfig("showIpAddress") ~= false
    local showPeers = barWidget.getConfig("showPeerCount") ~= false

    if not compact then
      if showIp and tailscaleIp ~= "" then
        table.insert(textParts, tailscaleIp)
      end
      if showPeers then
        table.insert(textParts, `{peerCount} peers`)
      end
    end

    if tailscaleIp ~= "" then
      table.insert(tooltipLines, `IP: {tailscaleIp}`)
    end
    table.insert(tooltipLines, `Peers: {peerCount}`)
  end

  barWidget.setText(table.concat(textParts, "  "))
  barWidget.setTooltip(table.concat(tooltipLines, "\n"))
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
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

noctalia.state.watch("peerCount", function(val)
  peerCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("tailscaleStatus", function(val)
  tailscaleStatus = tostring(val or "Disconnected")
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
