-- Pomodoro — bar widget.

local running = false
local remainingSeconds = 0
local currentMode = 0
local completedSessions = 0

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

local function render()
  local glyph = "clock"
  if currentMode == 0 then
    glyph = "brain"
  else
    glyph = "coffee"
  end

  local color = "on_surface_variant"
  if running then
    color = "primary"
  end

  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(color)

  barWidget.setText(formatTime(remainingSeconds))

  local modeStr = "Work"
  if currentMode == 1 then
    modeStr = "Short Break"
  elseif currentMode == 2 then
    modeStr = "Long Break"
  end

  local statusStr = if running then "Running" else "Paused"
  barWidget.setTooltip(`Pomodoro ({modeStr})\nStatus: {statusStr}\nSessions: {completedSessions}\nClick to toggle desktop widget`)
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("running", function(val)
  running = val == true
  render()
end)

noctalia.state.watch("remainingSeconds", function(val)
  remainingSeconds = tonumber(val) or 0
  render()
end)

noctalia.state.watch("mode", function(val)
  currentMode = tonumber(val) or 0
  render()
end)

noctalia.state.watch("completedSessions", function(val)
  completedSessions = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(1000)
  render()
end
