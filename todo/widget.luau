-- Todo List — bar widget.

local activeCount = 0

local function render()
  barWidget.setGlyph("clipboard-check")
  
  local colorKey = barWidget.getConfig("iconColor") or "primary"
  barWidget.setGlyphColor(colorKey)

  local text = ""
  if activeCount == 1 then
    text = (noctalia.tr("bar_widget.todo_count_singular") or "{count} todo"):gsub("{count}", tostring(activeCount))
  else
    text = (noctalia.tr("bar_widget.todo_count_plural") or "{count} todos"):gsub("{count}", tostring(activeCount))
  end
  
  barWidget.setText(text)
  barWidget.setTooltip(`{text}\nClick to toggle desktop widget edit mode`)
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("active_count", function(val)
  activeCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
