-- mpvpaper — bar widget.

local currentWallpaper = ""
local isPaused = false

local function render()
  barWidget.setGlyph("image")
  if isPaused then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("mpvpaper: Paused — click to resume")
  else
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    local wp = currentWallpaper ~= "" and currentWallpaper or "Wallpaper"
    barWidget.setTooltip("mpvpaper: " .. wp .. " | Click to pause, scroll to change")
  end
end

function onClick()
  noctalia.state.set("command", "toggle-pause")
end

function onScrollUp()
  noctalia.state.set("command", "next")
end

function onScrollDown()
  noctalia.state.set("command", "prev")
end

noctalia.state.watch("currentWallpaper", function(val)
  currentWallpaper = val or ""
  render()
end)

noctalia.state.watch("isPaused", function(val)
  isPaused = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
