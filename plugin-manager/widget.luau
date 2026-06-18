-- Plugin Manager — bar widget.

local pluginCount = 0

local function render()
  local iconColor = barWidget.getConfig("iconColor") or "on_surface"
  barWidget.setGlyph("puzzle")
  barWidget.setGlyphColor(iconColor)
  barWidget.setText(tostring(pluginCount))
  barWidget.setTooltip("Plugin Manager: " .. pluginCount .. " plugins — click to open")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("pluginCount", function(val)
  pluginCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
