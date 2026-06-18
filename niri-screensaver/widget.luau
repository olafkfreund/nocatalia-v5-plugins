-- Niri Screensaver — bar widget.

local isLocked = false
local enabled = true

local function render()
  barWidget.setGlyph("lock")
  if isLocked then
    barWidget.setGlyphColor("warning")
    barWidget.setText("")
    barWidget.setTooltip("Screen is locked — click to unlock")
  elseif enabled then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Niri Screensaver — click to lock screen")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Niri Screensaver: Disabled")
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

noctalia.state.watch("isLocked", function(val)
  isLocked = val == true
  render()
end)

noctalia.state.watch("enabled", function(val)
  enabled = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
