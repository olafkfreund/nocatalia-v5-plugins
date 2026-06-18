-- Mini Docker — bar widget.

local runningCount = 0
local totalCount = 0
local dockerAvailable = false

local function render()
  if not dockerAvailable then
    barWidget.setGlyph("box")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Docker not available")
    return
  end

  local activeColor = barWidget.getConfig("activeColor") or "primary"
  local iconColor = barWidget.getConfig("iconColor") or "none"

  barWidget.setGlyph("box")

  if runningCount > 0 then
    if iconColor ~= "none" and iconColor ~= "" then
      barWidget.setGlyphColor(iconColor)
    else
      barWidget.setGlyphColor(activeColor)
    end
    barWidget.setText(tostring(runningCount))
    barWidget.setTooltip(runningCount .. " running / " .. totalCount .. " total — right-click to stop all")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Docker: No running containers | " .. totalCount .. " total")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

function onRightClick()
  if runningCount > 0 then
    noctalia.state.set("command", "stop-all")
  else
    noctalia.state.set("command", "start-all")
  end
end

noctalia.state.watch("runningCount", function(val)
  runningCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("totalCount", function(val)
  totalCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("dockerAvailable", function(val)
  dockerAvailable = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
