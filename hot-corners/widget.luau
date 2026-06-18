-- Hot Corners — indicator widget (no bar widget for desktop-only plugin).

local enabled = true

local function render()
  barWidget.setGlyph("corners")
  if enabled then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Hot Corners: Active — click to disable")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("Hot Corners: Disabled — click to enable")
  end
  barWidget.setText("")
end

function onClick()
  noctalia.state.set("command", "toggle")
end

noctalia.state.watch("enabled", function(val)
  enabled = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
