-- SSH Sessions — bar widget.

local activeCount = 0
local tooltipText = ""

local function render()
  barWidget.setGlyph("terminal")
  if activeCount > 0 then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(activeCount))
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
  end
  barWidget.setTooltip(tooltipText ~= "" and tooltipText or (noctalia.tr("bar.noSessions") or "No active SSH sessions"))
end

function onClick()
  -- Toggle launcher with >ssh prefix
  noctalia.runAsync("noctalia msg panel-toggle launcher \">ssh \"")
end

noctalia.state.watch("activeCount", function(val)
  activeCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("tooltipText", function(val)
  tooltipText = tostring(val or "")
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
