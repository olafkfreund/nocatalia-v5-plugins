-- Polkit Agent — indicator widget.

local agentRunning = false

local function render()
  barWidget.setGlyph("shield")
  if agentRunning then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("Polkit Agent: Running")
  else
    barWidget.setGlyphColor("error")
    barWidget.setTooltip("Polkit Agent: Not running — authentication may fail!")
  end
  barWidget.setText("")
end

noctalia.state.watch("agentRunning", function(val)
  agentRunning = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
