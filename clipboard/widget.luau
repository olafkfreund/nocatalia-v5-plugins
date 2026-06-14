-- Clipboard — bar widget.
-- Prefills the launcher prefix /clip to search history on click.

local function render()
  barWidget.setGlyph("clipboard")
  barWidget.setGlyphColor("on_surface")
  barWidget.setTooltip("Clipboard Manager\nClick to search clipboard history")
end

function onClick()
  noctalia.runAsync("qs -c noctalia-shell ipc call launcher toggle")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
