-- Monique — bar widget.

local currentProfile = ""
local installed = false

local function render()
  barWidget.setGlyph("gauge")
  if not installed then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Monique: Not installed")
    return
  end

  local activeColor = barWidget.getConfig("activeColor") or "primary"
  local showLabel = barWidget.getConfig("showProfileLabel") ~= false
  barWidget.setGlyphColor(activeColor)
  if showLabel and currentProfile ~= "" then
    barWidget.setText(currentProfile)
  else
    barWidget.setText("")
  end
  barWidget.setTooltip("Monique: Profile '" .. currentProfile .. "' — click to refresh")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("currentProfile", function(val)
  currentProfile = val or ""
  render()
end)

noctalia.state.watch("installed", function(val)
  installed = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
