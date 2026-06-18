-- Mirror Mirror — bar widget.

local isMirrored = false
local monitorCount = 0

local function render()
  barWidget.setGlyph("monitor")
  if isMirrored then
    barWidget.setGlyphColor("primary")
    barWidget.setText("")
    barWidget.setTooltip("Mirror Mirror: Mirroring active — click to stop")
  else
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    barWidget.setTooltip("Mirror Mirror: " .. monitorCount .. " monitor(s) — click to mirror")
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

noctalia.state.watch("isMirrored", function(val)
  isMirrored = val == true
  render()
end)

noctalia.state.watch("monitorCount", function(val)
  monitorCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
