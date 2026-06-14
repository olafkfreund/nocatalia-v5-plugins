-- Agent Session Status — bar widget.
-- Displays the count of active agent sessions.

local runningCount = 0
local hideWhenEmpty = false

local function render()
  if hideWhenEmpty and runningCount == 0 then
    barWidget.setText("")
    barWidget.setGlyph("")
    return
  end

  local glyph = if runningCount > 0 then "bot" else "bot-off"
  barWidget.setGlyph(glyph)

  local colorKey = if runningCount > 0 then "primary" else "on_surface_variant"
  barWidget.setGlyphColor(colorKey)

  barWidget.setText(tostring(runningCount))

  local tooltipPattern = noctalia.tr("bar.tooltip") or "{count} running agent sessions"
  local tooltip = string.gsub(tooltipPattern, "{count}", tostring(runningCount))
  tooltip ..= "\n\nLeft-click: Prune inactive sessions\nRight-click: Restart service"
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.state.set("command", "prune")
end

function onRightClick()
  noctalia.state.set("command", "restart")
end

noctalia.state.watch("runningCount", function(val)
  runningCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  hideWhenEmpty = barWidget.getConfig("hideWhenEmpty") == true
  render()
end
