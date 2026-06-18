-- MIME App GUI — bar widget.

local typeCount = 0

local function render()
  local iconColor = barWidget.getConfig("iconColor") or "on_surface"
  barWidget.setGlyph("apps")
  barWidget.setGlyphColor(iconColor)
  barWidget.setText("")
  barWidget.setTooltip("MIME Apps: " .. typeCount .. " associations — click to manage")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("typeCount", function(val)
  typeCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
