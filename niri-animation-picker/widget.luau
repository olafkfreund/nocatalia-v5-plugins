-- Niri Animation Picker — bar widget.

local animationCount = 0
local currentAnimation = ""

local function render()
  local iconColor = barWidget.getConfig("iconColor") or "on_surface"
  barWidget.setGlyph("sparkles")
  barWidget.setGlyphColor(iconColor)
  if currentAnimation ~= "" then
    barWidget.setText(currentAnimation)
    barWidget.setTooltip("Niri Animation: " .. currentAnimation .. " (" .. animationCount .. " presets)")
  else
    barWidget.setText("")
    barWidget.setTooltip("Niri Animation Picker: " .. animationCount .. " presets")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("animationCount", function(val)
  animationCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("currentAnimation", function(val)
  currentAnimation = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
