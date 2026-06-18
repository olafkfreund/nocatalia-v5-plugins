-- Monitor Layout — bar widget.

local monitorCount = 0
local backend = "auto"

local function render()
  barWidget.setGlyph("monitor")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText(tostring(monitorCount))
  barWidget.setTooltip("Monitor Layout: " .. monitorCount .. " monitor(s) [" .. backend .. "] — click to manage")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("monitorCount", function(val)
  monitorCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("backend", function(val)
  backend = val or "auto"
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
