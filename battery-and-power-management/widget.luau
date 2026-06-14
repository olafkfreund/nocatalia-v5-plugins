-- Battery & Power Management — bar widget.

local batPercent = 0
local wattNum = 0.0
local batStatus = "Unknown"
local timeRemaining = "..."

local function getStatusText(status)
  local key = "battery.status_unknown"
  if status == "Charging" then key = "battery.status_charging"
  elseif status == "Full" then key = "battery.status_full"
  elseif status == "Discharging" then key = "battery.status_discharging"
  elseif status == "Not charging" then key = "battery.status_not_charging"
  end
  return noctalia.tr(key) or status
end

local function render()
  local isCharging = (batStatus == "Charging" or batStatus == "Full")
  local glyph = if isCharging then "battery-charging" else "battery-4"
  barWidget.setGlyph(glyph)

  local colorKey = if isCharging then "primary" else "on_surface"
  barWidget.setGlyphColor(colorKey)

  local indicator = if batStatus == "Charging" then "+" else "-"
  local label = string.format("%d%% %s%.1fW", batPercent, indicator, wattNum)
  barWidget.setText(label)

  local statusText = getStatusText(batStatus)
  local tooltip = `Battery & Power\nStatus: {statusText}`
  
  if isCharging then
    local fmt = noctalia.tr("battery.time_to_full") or "Time to full: {time}"
    tooltip ..= "\n" .. string.gsub(fmt, "{time}", timeRemaining)
  elseif batStatus == "Discharging" then
    local fmt = noctalia.tr("battery.remaining") or "Remaining: {time}"
    tooltip ..= "\n" .. string.gsub(fmt, "{time}", timeRemaining)
  else
    tooltip ..= string.format("\nPower Draw: %.1f W", wattNum)
  end
  
  tooltip ..= "\n\nClick to open controls"
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center") -- Toggle control-center panel
end

noctalia.state.watch("batPercent", function(val)
  batPercent = tonumber(val) or 0
  render()
end)

noctalia.state.watch("batStatus", function(val)
  batStatus = if type(val) == "string" then val else "Unknown"
  render()
end)

noctalia.state.watch("wattNum", function(val)
  wattNum = tonumber(val) or 0.0
  render()
end)

noctalia.state.watch("timeRemaining", function(val)
  timeRemaining = if type(val) == "string" then val else "..."
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
