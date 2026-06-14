-- Color Scheme Creator — bar widget.
-- Opens the theme launcher on click.

local function render()
  barWidget.setGlyph("palette")
  local colorKey = barWidget.getConfig("iconColor") or "primary"
  barWidget.setGlyphColor(colorKey)
  barWidget.setTooltip("Theme Manager\nClick to change theme")
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle launcher \"/theme \"")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
