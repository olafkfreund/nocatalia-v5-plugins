-- Shell Profiles — bar widget.

local profileCount = 0
local currentProfile = ""

local function render()
  local iconName = barWidget.getConfig("icon") or "wand"
  local iconColor = barWidget.getConfig("iconColor") or "primary"

  barWidget.setGlyph(iconName)
  barWidget.setGlyphColor(iconColor)

  if currentProfile ~= "" then
    barWidget.setText(currentProfile)
    barWidget.setTooltip("Shell Profile: " .. currentProfile .. " (" .. profileCount .. " available) — click to refresh")
  else
    barWidget.setText("")
    barWidget.setTooltip("Shell Profiles: " .. profileCount .. " available — click to apply first")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("profileCount", function(val)
  profileCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("currentProfile", function(val)
  currentProfile = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
