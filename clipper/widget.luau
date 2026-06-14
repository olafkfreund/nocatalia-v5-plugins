-- Clipper — bar widget.

local function render()
  barWidget.setGlyph("notes")
  barWidget.setGlyphColor("primary")
  barWidget.setTooltip("Clipper Manager\nClick to manage clipboard & notecards")
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle launcher \"/clipper \"")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
