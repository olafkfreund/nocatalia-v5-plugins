-- Mullvad VPN — desktop widget.

local installed = false
local vpnState = "disconnected"
local locked = false
local currentLoc = nil
local visibleLoc = nil
local lockdown = false
local autoconnect = false
local lan = "allow"
local daysLeft = 9999
local relaySelection = nil
local relayList = {}

local clickFuncs = {}

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

function toggleVpnConn()
  if vpnState == "connected" or vpnState == "connecting" then
    noctalia.state.set("command", { action = "disconnect" })
  else
    noctalia.state.set("command", { action = "connect" })
  end
end

function reconnectVpnConn()
  noctalia.state.set("command", { action = "reconnect" })
end

function toggleLockdownMode()
  noctalia.state.set("command", { action = "toggle_lockdown", on = not lockdown })
end

function toggleAutoConnectMode()
  noctalia.state.set("command", { action = "toggle_autoconnect", on = not autoconnect })
end

function toggleLanMode()
  noctalia.state.set("command", { action = "toggle_lan", allow = lan ~= "allow" })
end

function setRelayAny()
  noctalia.state.set("command", { action = "set_location", country = "" })
end

local function render()
  -- Clear previous callbacks
  for name, _ in clickFuncs do
    _G[name] = nil
  end
  clickFuncs = {}

  local title = "Mullvad VPN"
  local subTitle = ""
  if daysLeft < 9999 then
    subTitle = `{daysLeft} days left`
  end

  local rows = {
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.label({ text = subTitle, fontSize = 11, color = "on_surface_variant" })
    })
  }

  if not installed then
    table.insert(rows, ui.label({ text = "Mullvad is not installed or not in PATH", fontSize = 12, color = "error" }))
    desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
    return
  end

  -- Status block
  local statusText = vpnState:upper()
  local statusColor = "on_surface"
  if vpnState == "connected" then
    statusColor = "success"
    if currentLoc then
      local flag = getFlagEmoji(currentLoc.country)
      statusText = `{flag} Connected to {currentLoc.city or currentLoc.country} ({currentLoc.ipv4})`
    end
  elseif vpnState == "connecting" or vpnState == "disconnecting" then
    statusColor = "primary"
  elseif locked then
    statusColor = "error"
    statusText = "BLOCKED / LOCKDOWN"
  end

  table.insert(rows, ui.label({ text = statusText, fontSize = 13, fontWeight = "semibold", color = statusColor }))

  -- Connection Actions
  table.insert(rows, ui.row({ gap = 8 }, {
    ui.button({
      text = if vpnState == "connected" or vpnState == "connecting" then "Disconnect" else "Connect",
      variant = "primary",
      onClick = "toggleVpnConn"
    }),
    ui.button({
      text = "Reconnect",
      variant = "outline",
      onClick = "reconnectVpnConn"
    })
  }))

  -- Quick toggles
  table.insert(rows, ui.row({ gap = 6 }, {
    ui.button({
      text = "Lockdown",
      variant = if lockdown then "primary" else "outline",
      onClick = "toggleLockdownMode"
    }),
    ui.button({
      text = "Auto-Connect",
      variant = if autoconnect then "primary" else "outline",
      onClick = "toggleAutoConnectMode"
    }),
    ui.button({
      text = "LAN Sharing",
      variant = if lan == "allow" then "primary" else "outline",
      onClick = "toggleLanMode"
    })
  }))

  -- Relay selector
  table.insert(rows, ui.label({ text = "Relay Location", fontSize = 13, fontWeight = "bold", color = "primary" }))

  local selectButtons = {
    ui.button({
      text = "Auto Select",
      variant = if not relaySelection or relaySelection.country == "" then "primary" else "outline",
      onClick = "setRelayAny"
    })
  }

  -- Display favorite/popular countries or first few countries
  local displayCount = 0
  for _, country in relayList do
    if displayCount >= 6 then break end
    displayCount += 1
    
    local cbName = `set_relay_{country.code}`
    _G[cbName] = function()
      noctalia.state.set("command", { action = "set_location", country = country.code })
    end
    clickFuncs[cbName] = true

    local flag = getFlagEmoji(country.code)
    local isSelected = relaySelection and relaySelection.country == country.code
    table.insert(selectButtons, ui.button({
      text = `{flag} {country.country}`,
      variant = if isSelected then "primary" else "outline",
      onClick = cbName
    }))
  end

  table.insert(rows, ui.row({ gap = 6 }, selectButtons))

  desktopWidget.render(ui.column({ gap = 12, padding = 16 }, rows))
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

noctalia.state.watch("lockdown", function(val)
  lockdown = val == true
  render()
end)

noctalia.state.watch("autoconnect", function(val)
  autoconnect = val == true
  render()
end)

noctalia.state.watch("lan", function(val)
  lan = tostring(val)
  render()
end)

noctalia.state.watch("days_left", function(val)
  daysLeft = tonumber(val) or 9999
  render()
end)

noctalia.state.watch("relay_selection", function(val)
  relaySelection = if type(val) == "table" then val else nil
  render()
end)

noctalia.state.watch("relay_list", function(val)
  relayList = if type(val) == "table" then val else {}
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
