-- Niri Overview Launcher — bar widget.

local isOpen = false

local function render()
  barWidget.setGlyph("grid")
  if isOpen then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Niri Overview: Open — click to close")
  else
    barWidget.setGlyphColor("on_surface")
    barWidget.setTooltip("Niri Overview Launcher — click to open")
  end
  barWidget.setText("")
end

function onClick()
  noctalia.state.set("command", "toggle")
end

noctalia.state.watch("isOpen", function(val)
  isOpen = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
