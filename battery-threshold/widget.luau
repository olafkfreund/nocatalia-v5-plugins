-- Battery Threshold Control — bar widget.

local currentThreshold = -1
local isAvailable = false

local function render()
  if not isAvailable then
    barWidget.setText("")
    barWidget.setGlyph("")
    return
  end

  barWidget.setGlyph("shield-heart")
  barWidget.setGlyphColor("primary")
  barWidget.setText(currentThreshold >= 0 and `{currentThreshold}%` or "...")
  barWidget.setTooltip(`Battery Charge Limit\nLimit: {currentThreshold}%\n\nClick to open controls`)
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center")
end

noctalia.state.watch("currentThreshold", function(val)
  currentThreshold = tonumber(val) or -1
  render()
end)

noctalia.state.watch("isAvailable", function(val)
  isAvailable = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
