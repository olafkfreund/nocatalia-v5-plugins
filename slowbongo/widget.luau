-- Slowbongo — bar widget. Bongo cat animation!

local isPlaying = false
local frame = 0
-- Bongo cat frames
local FRAMES = {"🐱", "😺", "😸", "😹"}
local IDLE = "🐱"

local function render()
  local catColor = barWidget.getConfig("catColor") or "primary"
  barWidget.setGlyph("cat")

  if isPlaying then
    local cat = FRAMES[(frame % #FRAMES) + 1] or IDLE
    barWidget.setGlyphColor(catColor)
    barWidget.setText(cat)
    barWidget.setTooltip("Slowbongo: 🥁 Playing!")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText(IDLE)
    barWidget.setTooltip("Slowbongo: Not playing")
  end
end

noctalia.state.watch("isPlaying", function(val)
  isPlaying = val == true
  render()
end)

noctalia.state.watch("frame", function(val)
  frame = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
