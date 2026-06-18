-- Screen Toolkit — bar widget.
local lastColor = ""
local function render()
  barWidget.setGlyph("tool")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip("Screen Toolkit" .. (lastColor ~= "" and (" | Last color: " .. lastColor) or "") .. " — click to open")
end
function onClick() noctalia.state.set("command", "pick-color") end
noctalia.state.watch("lastColor", function(val) lastColor = val or ""; render() end)
function update() noctalia.setUpdateInterval(0); render() end
