-- Hyprland Steam Overlay — bar widget.
local isOpen = false
local steamRunning = false
local function render()
  barWidget.setGlyph("gamepad")
  if not steamRunning then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("Steam Overlay: Steam not running")
  elseif isOpen then
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("Steam Overlay: Open — click to close")
  else
    barWidget.setGlyphColor("on_surface")
    barWidget.setTooltip("Steam Overlay: Click to open")
  end
  barWidget.setText("")
end
function onClick() noctalia.state.set("command", "toggle") end
noctalia.state.watch("isOpen", function(val) isOpen = val == true; render() end)
noctalia.state.watch("steamRunning", function(val) steamRunning = val == true; render() end)
function update() noctalia.setUpdateInterval(0); render() end
