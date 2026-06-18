-- DeskVis — bar widget.
local isActive = false
local function render()
  barWidget.setGlyph("activity")
  if isActive then barWidget.setGlyphColor("primary") barWidget.setTooltip("DeskVis: Active — click to stop")
  else barWidget.setGlyphColor("on_surface_variant") barWidget.setTooltip("DeskVis: Inactive — click to start") end
  barWidget.setText("")
end
function onClick() noctalia.state.set("command", "toggle") end
noctalia.state.watch("isActive", function(val) isActive = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
