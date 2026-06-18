-- Workspace Overview — bar widget.

local isOpen = false

local function render()
  barWidget.setGlyph("layout-grid")
  if isOpen then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Workspace Overview: Open — click to close")
  else
    barWidget.setGlyphColor("on_surface")
    barWidget.setTooltip("Workspace Overview — click to toggle")
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
