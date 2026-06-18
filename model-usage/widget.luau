-- Model Usage — bar widget.
local totalCost = "0.00"
local function render()
  barWidget.setGlyph("cpu")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("$" .. totalCost)
  barWidget.setTooltip("AI Model Usage: $" .. totalCost .. " — click to refresh")
end
function onClick() noctalia.state.set("command", "refresh") end
noctalia.state.watch("totalCost", function(val) totalCost = val or "0.00"; render() end)
function update() noctalia.setUpdateInterval(0); render() end
