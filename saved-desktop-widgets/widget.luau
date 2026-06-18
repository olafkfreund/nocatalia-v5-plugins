-- Saved Desktop Widgets — bar widget.
local widgetCount = 0
local function render()
  barWidget.setGlyph("layout-dashboard")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText(tostring(widgetCount))
  barWidget.setTooltip("Desktop Widgets: " .. widgetCount .. " saved — click to manage")
end
function onClick() noctalia.state.set("command", "refresh") end
noctalia.state.watch("widgetCount", function(val) widgetCount = tonumber(val) or 0; render() end)
function update() noctalia.setUpdateInterval(0); render() end
