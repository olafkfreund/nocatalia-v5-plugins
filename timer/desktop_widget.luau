-- Timer — desktop widget.

local mode = "countdown"
local running = false
local remaining = 300
local elapsed = 0
local total = 300

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

local function render()
  local duration = if mode == "countdown" then remaining else elapsed
  local progressVal = if mode == "countdown" and total > 0 then remaining / total else 0

  local rows = {
    ui.label({
      text = formatTime(duration),
      fontSize = 34,
      fontWeight = "bold",
      color = mode == "countdown" and remaining == 0 and "error" or "primary",
    }),
    ui.progress({
      progress = progressVal,
      fill = "primary",
      width = 160,
      height = 6,
      radius = 3,
    }),
    ui.row({ gap = 8 }, {
      ui.button({
        text = running and "Pause" or "Start",
        variant = "primary",
        onClick = "toggleTimer",
      }),
      ui.button({
        text = "Reset",
        variant = "outline",
        onClick = "resetTimer",
      }),
      ui.button({
        text = mode == "countdown" and "Stopwatch" or "Countdown",
        variant = "outline",
        onClick = "toggleMode",
      }),
    })
  }

  desktopWidget.render(ui.column({ gap = 10, align = "center", padding = 16 }, rows))
end

function toggleTimer()
  local r = noctalia.state.get("timer_running") == true
  noctalia.state.set("timer_running", not r)
end

function resetTimer()
  noctalia.state.set("timer_running", false)
  if mode == "countdown" then
    local defaultDur = tonumber(noctalia.getConfig("defaultDuration")) or 300
    noctalia.state.set("timer_remaining", defaultDur)
    noctalia.state.set("timer_total", defaultDur)
  else
    noctalia.state.set("timer_elapsed", 0)
  end
end

function toggleMode()
  noctalia.state.set("timer_running", false)
  local newMode = if mode == "countdown" then "stopwatch" else "countdown"
  noctalia.state.set("timer_mode", newMode)
  resetTimer()
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

noctalia.state.watch("timer_total", function(val)
  total = tonumber(val) or 300
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
