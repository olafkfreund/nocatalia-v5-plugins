-- Openhue — bar widget.

local available = false
local anyOn = false
local lightCount = 0

local function render()
  barWidget.setGlyph("lightbulb")

  if not available then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Openhue: CLI not configured. Run 'openhue configure'")
    return
  end

  if anyOn then
    barWidget.setGlyphColor("warning")
    barWidget.setText("")
    barWidget.setTooltip("Hue lights: " .. lightCount .. " lights | Some on — click to turn all off")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Hue lights: All off — click to turn on")
  end
end

function onClick()
  noctalia.state.set("command", "toggle-all")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("available", function(val)
  available = val == true
  render()
end)

noctalia.state.watch("anyOn", function(val)
  anyOn = val == true
  render()
end)

noctalia.state.watch("lightCount", function(val)
  lightCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
