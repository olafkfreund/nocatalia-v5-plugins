-- Battery Monitor Plus — bar widget.

local ok = false
local capacity = -1
local status = "Unknown"
local powerWatts = -1.0
local timeToEmpty = 0
local timeToFull = 0
local showPower = true
local showTime = true
local hideNotDetected = true

local function formatDurationCompact(seconds)
  if seconds <= 0 then return "" end
  local totalMinutes = math.max(1, math.round(seconds / 60))
  local hours = math.floor(totalMinutes / 60)
  local minutes = totalMinutes % 60
  if hours > 0 then
    return if minutes > 0 then `{hours}h{minutes}m` else `{hours}h`
  end
  return `{minutes}m`
end

local function render()
  if not ok and hideNotDetected then
    barWidget.setText("")
    barWidget.setGlyph("")
    return
  end

  local isCharging = (status == "Charging" or status == "Full")
  local glyph = if isCharging then "battery-charging" else "battery-4"
  barWidget.setGlyph(glyph)

  local colorKey = if isCharging then "primary" else "on_surface"
  barWidget.setGlyphColor(colorKey)

  local textParts = {}
  if capacity >= 0 then
    table.insert(textParts, `{capacity}%`)
  end

  if showPower and powerWatts > 0 then
    local sign = if status == "Charging" then "+" else "-"
    table.insert(textParts, string.format(" %s%.1fW", sign, powerWatts))
  end

  if showTime then
    local sec = if status == "Charging" then timeToFull else timeToEmpty
    local dur = formatDurationCompact(sec)
    if dur ~= "" then
      table.insert(textParts, ` ({dur})`)
    end
  end

  barWidget.setText(table.concat(textParts))

  -- Tooltip
  local statusText = status
  if status == "Charging" then statusText = "Charging"
  elseif status == "Discharging" then statusText = "Discharging"
  elseif status == "Full" then statusText = "Fully charged"
  elseif status == "Not charging" then statusText = "Plugged in"
  end
  
  barWidget.setTooltip(`Battery Monitor Plus\nStatus: {statusText}\nClick to open controls`)
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center")
end

noctalia.state.watch("ok", function(val)
  ok = val == true
  render()
end)

noctalia.state.watch("capacity", function(val)
  capacity = tonumber(val) or -1
  render()
end)

noctalia.state.watch("status", function(val)
  status = if type(val) == "string" then val else "Unknown"
  render()
end)

noctalia.state.watch("powerWatts", function(val)
  powerWatts = tonumber(val) or -1.0
  render()
end)

noctalia.state.watch("timeToEmpty", function(val)
  timeToEmpty = tonumber(val) or 0
  render()
end)

noctalia.state.watch("timeToFull", function(val)
  timeToFull = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  showPower = barWidget.getConfig("showPowerInBar") ~= false
  showTime = barWidget.getConfig("showTimeInBar") ~= false
  hideNotDetected = barWidget.getConfig("hideIfNotDetected") ~= false
  render()
end
