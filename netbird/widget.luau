-- Netbird — bar widget.

local connected = false
local ipAddress = ""
local peerCount = 0
local netbirdInstalled = false

local function render()
  local hideDisconnected = barWidget.getConfig("hideDisconnected") == true
  local compactMode = barWidget.getConfig("compactMode") == true
  local showIp = barWidget.getConfig("showIpAddress") ~= false

  if not netbirdInstalled then
    barWidget.setVisible(false)
    return
  end

  if not connected and hideDisconnected then
    barWidget.setVisible(false)
    return
  end

  barWidget.setVisible(true)
  barWidget.setGlyph("network")

  if connected then
    barWidget.setGlyphColor("primary")
    if compactMode then
      barWidget.setText("")
    elseif showIp and ipAddress ~= "" then
      barWidget.setText(ipAddress)
    else
      barWidget.setText("")
    end
    local tooltip = "Netbird: Connected"
    if peerCount > 0 then
      tooltip = tooltip .. " (" .. peerCount .. " peers)"
    end
    if ipAddress ~= "" then
      tooltip = tooltip .. " | IP: " .. ipAddress
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Netbird: Disconnected — click to connect")
  end
end

function onClick()
  if connected then
    noctalia.state.set("command", "down")
  else
    noctalia.state.set("command", "up")
  end
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("ipAddress", function(val)
  ipAddress = val or ""
  render()
end)

noctalia.state.watch("peerCount", function(val)
  peerCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("netbirdInstalled", function(val)
  netbirdInstalled = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
