-- Mawaqit — bar widget.

local nextPrayer = ""
local nextPrayerTime = ""
local countdown = ""

local function render()
  local iconColor = barWidget.getConfig("iconColor") or "none"
  local activeColor = barWidget.getConfig("activeColor") or "primary"
  local showCountdown = barWidget.getConfig("showCountdown") ~= false

  barWidget.setGlyph("building-mosque")

  if iconColor ~= "none" and iconColor ~= "" then
    barWidget.setGlyphColor(iconColor)
  else
    barWidget.setGlyphColor("on_surface")
  end

  if nextPrayer ~= "" then
    local display = nextPrayer
    if showCountdown and countdown ~= "" then
      display = nextPrayer .. " " .. countdown
    end
    barWidget.setText(display)
    barWidget.setTooltip("Next prayer: " .. nextPrayer .. " at " .. nextPrayerTime .. " (" .. countdown .. ")")
  else
    barWidget.setText("")
    barWidget.setTooltip("Prayer times loading...")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("nextPrayer", function(val)
  nextPrayer = val or ""
  render()
end)

noctalia.state.watch("nextPrayerTime", function(val)
  nextPrayerTime = val or ""
  render()
end)

noctalia.state.watch("countdown", function(val)
  countdown = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
