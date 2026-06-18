-- Valent Connect — bar widget.

local deviceName = ""
local connected = false
local valentAvailable = false

local function render()
  barWidget.setGlyph("smartphone")

  if not valentAvailable then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Valent not running")
    return
  end

  if connected then
    barWidget.setGlyphColor("primary")
    local display = deviceName ~= "" and deviceName or "Device"
    barWidget.setText("")
    barWidget.setTooltip("Connected: " .. display)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Valent: No device connected")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("deviceName", function(val)
  deviceName = val or ""
  render()
end)

noctalia.state.watch("valentAvailable", function(val)
  valentAvailable = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
