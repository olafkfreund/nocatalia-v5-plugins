-- Notes Scratchpad — bar widget.

local charCount = 0

local function render()
  barWidget.setGlyph("pencil")
  if charCount > 0 then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(charCount))
    barWidget.setTooltip("Scratchpad: " .. charCount .. " chars — click to open")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Scratchpad: Empty — click to open")
  end
end

function onClick()
  noctalia.state.set("command", "load")
end

noctalia.state.watch("charCount", function(val)
  charCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
