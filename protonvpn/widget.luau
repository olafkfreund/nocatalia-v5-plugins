-- ProtonVPN — bar widget.
-- Displays a shield icon whose colour reflects VPN connection state.
-- Clicking the widget dispatches a toggle command to the service.

local connected = false
local acting = false
local serverName = ""
local serverLocation = ""
local ipAddress = ""

-- ── Render ────────────────────────────────────────────────────────────────────

local function render()
  if acting then
    -- Show reload glyph while a command is in flight.
    barWidget.setGlyph("reload")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("bar.working") or "ProtonVPN: Working...")
    barWidget.setVisible(true)
    return
  end

  if connected then
    barWidget.setGlyph("shield-lock")

    local color = barWidget.getConfig("connectedColor") or "primary"
    barWidget.setGlyphColor(color)

    -- Build text: show server name when display mode is "alwaysShow" or "connectedOnly".
    local displayMode = barWidget.getConfig("displayMode") or "alwaysShow"
    if displayMode == "alwaysShow" or displayMode == "connectedOnly" then
      barWidget.setText(serverName)
    else
      barWidget.setText("")
    end

    -- Build tooltip.
    local tooltipParts = {}
    if serverName ~= "" then
      table.insert(tooltipParts, "Server: " .. serverName)
    end
    if serverLocation ~= "" then
      table.insert(tooltipParts, "Location: " .. serverLocation)
    end
    if ipAddress ~= "" then
      table.insert(tooltipParts, "IP: " .. ipAddress)
    end
    if #tooltipParts > 0 then
      barWidget.setTooltip(table.concat(tooltipParts, "\n"))
    else
      barWidget.setTooltip(noctalia.tr("bar.connected") or "ProtonVPN: Connected")
    end

    barWidget.setVisible(true)
  else
    -- Disconnected state.
    local displayMode = barWidget.getConfig("displayMode") or "alwaysShow"
    if displayMode == "alwaysHide" then
      barWidget.setVisible(false)
      return
    end

    local color = barWidget.getConfig("disconnectedColor") or "on_surface_variant"
    if color == "none" then
      barWidget.setVisible(false)
      return
    end

    barWidget.setGlyph("shield")
    barWidget.setGlyphColor(color)
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("bar.disconnected-state") or "ProtonVPN: Disconnected")
    barWidget.setVisible(true)
  end
end

-- ── State watchers ────────────────────────────────────────────────────────────

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("acting", function(val)
  acting = val == true
  render()
end)

noctalia.state.watch("serverName", function(val)
  serverName = tostring(val or "")
  render()
end)

noctalia.state.watch("serverLocation", function(val)
  serverLocation = tostring(val or "")
  render()
end)

noctalia.state.watch("ipAddress", function(val)
  ipAddress = tostring(val or "")
  render()
end)

-- ── Interactions ──────────────────────────────────────────────────────────────

function onClick()
  noctalia.state.set("command", { action = "toggle" })
end

function onRightClick()
  -- No-op: right-click context menu is handled by the shell framework.
end

-- ── Periodic update ───────────────────────────────────────────────────────────

function update()
  render()
end
