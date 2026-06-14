-- Coin Flipper — bar widget.

local state = "idle" -- idle | flipping
local result = ""

local function render()
  barWidget.setGlyph("coin")
  
  local colorKey = barWidget.getConfig("iconColor") or "primary"
  barWidget.setGlyphColor(colorKey)

  if state == "flipping" then
    barWidget.setText("...")
    barWidget.setTooltip("Flipping coin...")
  elseif result ~= "" then
    barWidget.setText(result)
    barWidget.setTooltip(`Last result: {result}\n\nClick to flip again`)
  else
    barWidget.setText("")
    barWidget.setTooltip("Click to flip a coin")
  end
end

local function flip()
  if state == "flipping" then return end
  state = "flipping"
  render()

  noctalia.setUpdateInterval(600)
end

function onClick()
  flip()
end

function update()
  if state == "flipping" then
    state = "idle"
    local isHeads = math.random() < 0.5
    result = if isHeads then noctalia.tr("common.heads") else noctalia.tr("common.tails")
    noctalia.notify("Coin Flipper", `It's {result}!`)
    noctalia.setUpdateInterval(0)
    render()
  else
    noctalia.setUpdateInterval(0)
    render()
  end
end
