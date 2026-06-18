-- Sticky Notes — bar widget.

local noteCount = 0

local function render()
  barWidget.setGlyph("sticky-note")
  if noteCount > 0 then
    barWidget.setGlyphColor("warning")
    barWidget.setText(tostring(noteCount))
    barWidget.setTooltip("Sticky Notes: " .. noteCount .. " note(s) — click to open")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Sticky Notes: No notes — click to add")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("noteCount", function(val)
  noteCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
