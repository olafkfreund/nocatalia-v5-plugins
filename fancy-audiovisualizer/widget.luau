-- Fancy Audio Visualizer — bar widget.
local isActive = false
local function render()
  barWidget.setGlyph("radio")
  if isActive then barWidget.setGlyphColor("primary") barWidget.setTooltip("Fancy Visualizer: Active")
  else barWidget.setGlyphColor("on_surface_variant") barWidget.setTooltip("Fancy Visualizer: Inactive") end
  barWidget.setText("")
end
function onClick() noctalia.state.set("command", "toggle") end
noctalia.state.watch("isActive", function(val) isActive = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
