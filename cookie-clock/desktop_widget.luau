-- Cookie Clock — desktop widget.
-- Displays a beautifully themed cookie-inspired digital clock.

local function render()
  local now = os.date("*t")
  local showSec = noctalia.getConfig("showSeconds") ~= false
  local dateStyle = noctalia.getConfig("dateStyle") or "bubble"

  local timeText = string.format("%02d:%02d", now.hour, now.min)
  if showSec then
    timeText = string.format("%02d:%02d:%02d", now.hour, now.min, now.sec)
  end

  local dateText = os.date("%A, %B %d")

  local children = {
    ui.label({
      text = "🍪 COOKIE CLOCK 🍪",
      fontSize = 12,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.label({
      text = timeText,
      fontSize = 32,
      fontWeight = "bold",
      color = "primary"
    })
  }

  if dateStyle == "bubble" then
    table.insert(children, ui.button({
      text = dateText,
      variant = "secondary"
    }))
  elseif dateStyle == "rect" then
    table.insert(children, ui.label({
      text = dateText,
      fontSize = 14,
      color = "on_surface_variant"
    }))
  end

  desktopWidget.render(ui.column({
    gap = 12,
    align = "center",
    padding = 20
  }, children))
end

function update()
  local showSec = noctalia.getConfig("showSeconds") ~= false
  noctalia.setUpdateInterval(showSec and 1000 or 15000)
  render()
end
