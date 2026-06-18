-- Music Search — bar widget.
local function render()
  barWidget.setGlyph("search")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip("Music Search — click to search")
end
function onClick() noctalia.state.set("command", "toggle") end
function update() noctalia.setUpdateInterval(0); render() end
