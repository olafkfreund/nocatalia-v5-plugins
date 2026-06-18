-- Simple Notes — bar widget.

local noteCount = 0

local function render()
  barWidget.setGlyph("notebook")

  local showCount = barWidget.getConfig("showCountInBar") ~= false

  if noteCount > 0 then
    barWidget.setGlyphColor("primary")
    if showCount then
      barWidget.setText(tostring(noteCount))
    else
      barWidget.setText("")
    end
    barWidget.setTooltip("Simple Notes: " .. noteCount .. " note(s)")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Simple Notes: No notes yet — click to open")
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
