-- Video Wallpaper — bar widget.
local isRunning = false
local function render()
  barWidget.setGlyph("video")
  if isRunning then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Video Wallpaper: Running — click to stop")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("Video Wallpaper: Stopped — click to open")
  end
  barWidget.setText("")
end
function onClick()
  if isRunning then noctalia.state.set("command", "stop")
  else noctalia.state.set("command", "refresh") end
end
noctalia.state.watch("isRunning", function(val) isRunning = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
