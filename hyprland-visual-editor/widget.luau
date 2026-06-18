-- Hyprland Visual Editor — bar widget.
local function render()
  barWidget.setGlyph("settings")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip("Hyprland Visual Editor — click to open")
end
function onClick() noctalia.state.set("command", "refresh") end
function update() noctalia.setUpdateInterval(0); render() end
