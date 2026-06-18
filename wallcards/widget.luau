-- Wallcards — bar widget.
local function render()
  barWidget.setGlyph("image")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip("Wallcards — click to browse wallpapers")
end
function onClick() noctalia.state.set("command", "refresh") end
function update() noctalia.setUpdateInterval(0); render() end
