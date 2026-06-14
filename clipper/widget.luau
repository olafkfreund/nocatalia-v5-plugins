-- Clipper — bar widget.

local function render()
  barWidget.setGlyph("notes")
  barWidget.setGlyphColor("primary")
  barWidget.setTooltip("Clipper Manager\nClick to manage clipboard & notecards")
end

function onClick()
  noctalia.runAsync("qs -c noctalia-shell ipc call launcher toggle")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
