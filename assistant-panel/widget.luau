-- Assistant Panel — bar widget.
-- Opens the launcher.

local function render()
  barWidget.setGlyph("message-code")
  barWidget.setGlyphColor("primary")
  barWidget.setTooltip("Assistant Panel\nClick to open AI Chat / Translation launcher")
end

function onClick()
  noctalia.runAsync("qs -c noctalia-shell ipc call launcher toggle")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
