-- Home Assistant Control — bar widget.

local connected = false
local errorMessage = ""

local function render()
  barWidget.setGlyph("home")
  if not connected then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Home Assistant: " .. (errorMessage ~= "" and errorMessage or "Not connected"))
  else
    barWidget.setGlyphColor("primary")
    barWidget.setText("")
    barWidget.setTooltip("Home Assistant: Connected — click to refresh")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("errorMessage", function(val)
  errorMessage = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
