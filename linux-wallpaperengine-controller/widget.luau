-- Linux Wallpaper Engine Controller — bar widget.
local isRunning = false
local function render()
  local iconColor = barWidget.getConfig("iconColor") or "on_surface"
  barWidget.setGlyph("wallpaper")
  if isRunning then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Wallpaper Engine: Running — click to open")
  else
    barWidget.setGlyphColor(iconColor)
    barWidget.setTooltip("Wallpaper Engine: Stopped — click to open")
  end
  barWidget.setText("")
end
function onClick() noctalia.state.set("command", "refresh") end
noctalia.state.watch("isRunning", function(val) isRunning = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
