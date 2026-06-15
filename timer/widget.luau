-- Timer — bar widget.

local mode = "countdown"
local running = false
local remaining = 300
local elapsed = 0

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

local function render()
  local icon = if mode == "stopwatch" then "stopwatch" else "hourglass"
  barWidget.setGlyph(icon)
  
  local colorKey = barWidget.getConfig("iconColor") or "primary"
  barWidget.setGlyphColor(colorKey)

  if running then
    local timeStr = if mode == "countdown" then formatTime(remaining) else formatTime(elapsed)
    barWidget.setText(timeStr)
    barWidget.setTooltip(`Timer running ({mode})\nTime: {timeStr}\nClick to pause`)
  else
    barWidget.setText("")
    barWidget.setTooltip("Timer / Stopwatch\nClick to toggle control panel")
  end
end

function onClick()
  local r = noctalia.state.get("timer_running") == true
  noctalia.state.set("timer_running", not r)
  render()
end

noctalia.state.watch("timer_mode", function(val)
  mode = if type(val) == "string" then val else "countdown"
  render()
end)

noctalia.state.watch("timer_running", function(val)
  running = val == true
  render()
end)

noctalia.state.watch("timer_remaining", function(val)
  remaining = tonumber(val) or 0
  render()
end)

noctalia.state.watch("timer_elapsed", function(val)
  elapsed = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(1000)
  render()
end
