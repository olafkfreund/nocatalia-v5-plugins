-- Parallax Wallpaper — bar widget.
local isActive = false
local function render()
  barWidget.setGlyph("layers")
  if isActive then barWidget.setGlyphColor("primary") barWidget.setTooltip("Parallax Wallpaper: Active")
  else barWidget.setGlyphColor("on_surface_variant") barWidget.setTooltip("Parallax Wallpaper: Inactive") end
  barWidget.setText("")
end
function onClick() noctalia.state.set("command", "toggle") end
noctalia.state.watch("isActive", function(val) isActive = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
