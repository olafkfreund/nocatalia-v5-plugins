-- Hello World — bar widget.

local function render()
  barWidget.setGlyph("world")
  
  local colorKey = barWidget.getConfig("iconColor") or "primary"
  barWidget.setGlyphColor(colorKey)

  local msg = barWidget.getConfig("message") or "Hello World"
  barWidget.setText("Hello")
  barWidget.setTooltip(`Hello World Widget\nMessage: {msg}\nClick to toggle desktop widget`)
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
