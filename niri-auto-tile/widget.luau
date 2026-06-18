-- Niri Auto Tile — bar widget.

local enabled = true
local tileMode = "auto"
local windowCount = 0

local function render()
  barWidget.setGlyph("layout-grid")
  if enabled then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(windowCount))
    barWidget.setTooltip("Auto Tile: " .. tileMode .. " (" .. windowCount .. " windows) — click to disable")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Auto Tile: Disabled — click to enable")
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

noctalia.state.watch("enabled", function(val)
  enabled = val == true
  render()
end)

noctalia.state.watch("tileMode", function(val)
  tileMode = val or "auto"
  render()
end)

noctalia.state.watch("windowCount", function(val)
  windowCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
