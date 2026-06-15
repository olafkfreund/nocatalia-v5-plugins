-- Hello World — desktop widget.

local function render()
  local msg = noctalia.getConfig("message") or "Hello World"

  desktopWidget.render(ui.column({
    gap = 8,
    align = "center",
    padding = 16
  }, {
    ui.label({
      text = "🌐 HELLO WORLD 🌐",
      fontSize = 12,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.label({
      text = msg,
      fontSize = 20,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.label({
      text = "Desktop Widget",
      fontSize = 11,
      color = "on_surface_variant"
    })
  }))
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
