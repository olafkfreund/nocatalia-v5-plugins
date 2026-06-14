-- Coin Flipper — desktop widget.

local state = "idle" -- idle | flipping
local result = ""

local function render()
  if state == "flipping" then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "Flipping...", fontSize = 24, fontWeight = "bold", color = "primary" })
    }))
    return
  end

  local rows = {
    ui.label({
      text = result ~= "" and result or "Flip Me!",
      fontSize = 28,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.button({
      text = "Flip Coin",
      variant = "primary",
      onClick = "startFlip"
    })
  }

  desktopWidget.render(ui.column({ gap = 12, align = "center" }, rows))
end

function startFlip()
  if state == "flipping" then return end
  state = "flipping"
  render()
  desktopWidget.setWantsSecondTicks(true)
end

function update()
  if state == "flipping" then
    state = "idle"
    desktopWidget.setWantsSecondTicks(false)
    local isHeads = math.random() < 0.5
    result = if isHeads then noctalia.tr("common.heads") else noctalia.tr("common.tails")
    noctalia.notify("Coin Flipper", `It's {result}!`)
  end
  render()
end
