-- Mullvad VPN — bar widget.

local installed = false
local vpnState = "disconnected"
local locked = false
local currentLoc = nil
local visibleLoc = nil

local function getFlagEmoji(code)
  if not code or #code ~= 2 then return "" end
  code = code:upper()
  local b1 = code:byte(1)
  local b2 = code:byte(2)
  local cp1 = 127462 + b1 - 65
  local cp2 = 127462 + b2 - 65
  local success, char = pcall(utf8.char, cp1, cp2)
  return if success then char else code
end

local function render()
  if not installed then
    barWidget.setGlyph("shield-x")
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip("Mullvad VPN is not installed")
    return
  end

  if vpnState == "error" then
    barWidget.setGlyph("shield-x")
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip("Mullvad VPN daemon error")
    return
  end

  local glyph = "shield"
  local color = "on_surface"
  
  if vpnState == "connected" then
    glyph = "shield"
    color = "primary"
  elseif vpnState == "connecting" or vpnState == "disconnecting" then
    glyph = "shield"
    color = "primary"
  elseif locked then
    glyph = "shield-off"
    color = "error"
  else
    glyph = "shield-off"
    color = "on_surface_variant"
  end

  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(color)

  -- Build display text
  local parts = {}
  local tooltipLines = { `Status: {vpnState}` }
  
  if vpnState == "connected" and currentLoc then
    local flag = getFlagEmoji(currentLoc.country)
    if barWidget.getConfig("showCountryFlag") ~= false and flag ~= "" then
      table.insert(parts, flag)
    end
    if barWidget.getConfig("showCityName") == true and currentLoc.city ~= "" then
      table.insert(parts, currentLoc.city)
    end
    if barWidget.getConfig("showIp") == true and currentLoc.ipv4 ~= "" then
      table.insert(parts, currentLoc.ipv4)
    end
    
    table.insert(tooltipLines, `Location: {currentLoc.city or ""}, {currentLoc.country or ""}`)
    table.insert(tooltipLines, `IP: {currentLoc.ipv4 or ""}`)
    if currentLoc.hostname ~= "" then
      table.insert(tooltipLines, `Server: {currentLoc.hostname}`)
    end
  else
    if visibleLoc then
      table.insert(tooltipLines, `Last Location: {visibleLoc.city or ""}, {visibleLoc.country or ""}`)
      table.insert(tooltipLines, `Last IP: {visibleLoc.ipv4 or ""}`)
    end
  end

  barWidget.setText(table.concat(parts, " "))
  barWidget.setTooltip(table.concat(tooltipLines, "\n"))
end

function onClick()
  if not installed then return end
  local action = barWidget.getConfig("clickAction") or "panel"
  if action == "toggle" then
    if vpnState == "connected" or vpnState == "connecting" then
      noctalia.state.set("command", { action = "disconnect" })
    else
      noctalia.state.set("command", { action = "connect" })
    end
  else
    noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
  end
end

noctalia.state.watch("installed", function(val)
  installed = val == true
  render()
end)

noctalia.state.watch("vpn_state", function(val)
  vpnState = tostring(val)
  render()
end)

noctalia.state.watch("locked", function(val)
  locked = val == true
  render()
end)

noctalia.state.watch("current_location", function(val)
  currentLoc = if type(val) == "table" then val else nil
  render()
end)

noctalia.state.watch("visible_location", function(val)
  visibleLoc = if type(val) == "table" then val else nil
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
