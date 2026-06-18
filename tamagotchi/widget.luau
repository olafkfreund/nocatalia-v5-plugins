-- Tamagotchi — bar widget.

local mood = "happy"
local isDead = false
local hunger = 50
local happiness = 70

local MOOD_ICONS = {
  happy = "😄",
  content = "🙂",
  bored = "😑",
  sad = "😢",
  critical = "😱",
  dead = "💀",
}

local function render()
  barWidget.setGlyph("heart")
  local icon = MOOD_ICONS[mood] or "🐾"
  barWidget.setText(icon)
  if isDead then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("Tamagotchi: 💀 Dead — click to revive!")
  elseif mood == "happy" then
    barWidget.setGlyphColor("success")
    barWidget.setTooltip("Tamagotchi: Happy! Hunger:" .. hunger .. " Happy:" .. happiness)
  elseif mood == "critical" then
    barWidget.setGlyphColor("error")
    barWidget.setTooltip("Tamagotchi: CRITICAL! Feed and play now!")
  else
    barWidget.setGlyphColor("warning")
    barWidget.setTooltip("Tamagotchi: " .. mood .. " | Hunger:" .. hunger .. " Happy:" .. happiness)
  end
end

function onClick()
  if isDead then
    noctalia.state.set("command", "revive")
  else
    noctalia.state.set("command", "feed")
  end
end

noctalia.state.watch("mood", function(val)
  mood = val or "happy"
  render()
end)

noctalia.state.watch("isDead", function(val)
  isDead = val == true
  render()
end)

noctalia.state.watch("hunger", function(val)
  hunger = tonumber(val) or 50
  render()
end)

noctalia.state.watch("happiness", function(val)
  happiness = tonumber(val) or 70
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
