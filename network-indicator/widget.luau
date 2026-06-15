-- Network Indicator — bar widget.

local rxSpeed = 0
local txSpeed = 0

local function formatSpeed(bytes)
  if bytes < 1024 then
    return string.format("%d B/s", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB/s", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format("%.1f MB/s", bytes / (1024 * 1024))
  else
    return string.format("%.1f GB/s", bytes / (1024 * 1024 * 1024))
  end
end

local function render()
  local byteThresholdActive = tonumber(barWidget.getConfig("byteThresholdActive")) or 5000
  local txActive = txSpeed >= byteThresholdActive
  local rxActive = rxSpeed >= byteThresholdActive

  local glyph = "arrow-up-down"
  local color = "on_surface_variant"

  if txActive and rxActive then
    color = "primary"
  elseif txActive then
    color = "primary"
  elseif rxActive then
    color = "primary"
  end

  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(color)

  local text = `▲ {formatSpeed(txSpeed)}  ▼ {formatSpeed(rxSpeed)}`
  barWidget.setText(text)

  local tooltip = `Network Traffic\nUpload: {formatSpeed(txSpeed)}\nDownload: {formatSpeed(rxSpeed)}\nClick to toggle desktop widget`
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("rxSpeed", function(val)
  rxSpeed = tonumber(val) or 0
  render()
end)

noctalia.state.watch("txSpeed", function(val)
  txSpeed = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(1000)
  render()
end
