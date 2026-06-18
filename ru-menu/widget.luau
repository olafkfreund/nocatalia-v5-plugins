-- RU Menu — bar widget.

local function render()
  barWidget.setGlyph("menu")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip("RU Menu — right-click for menu")
end

function onClick()
  -- Menu opens via panel
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
