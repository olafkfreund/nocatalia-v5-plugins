-- Pomodoro — desktop widget.

local running = false
local remainingSeconds = 0
local currentMode = 0
local completedSessions = 0

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

local function getDuration(mode)
  if mode == 0 then
    return (tonumber(noctalia.getConfig("workDuration")) or 25) * 60
  elseif mode == 1 then
    return (tonumber(noctalia.getConfig("shortBreakDuration")) or 5) * 60
  elseif mode == 2 then
    return (tonumber(noctalia.getConfig("longBreakDuration")) or 15) * 60
  end
  return 25 * 60
end

function toggleTimer()
  if running then
    noctalia.state.set("command", { action = "pause" })
  else
    noctalia.state.set("command", { action = "start" })
  end
end

function skipTimer()
  noctalia.state.set("command", { action = "skip" })
end

function resetTimer()
  noctalia.state.set("command", { action = "reset" })
end

function resetAllTimer()
  noctalia.state.set("command", { action = "reset_all" })
end

function setModeWork()
  noctalia.state.set("command", { action = "set_mode", mode = 0 })
end

function setModeShort()
  noctalia.state.set("command", { action = "set_mode", mode = 1 })
end

function setModeLong()
  noctalia.state.set("command", { action = "set_mode", mode = 2 })
end

local function render()
  local modeStr = "Work"
  local modeColor = "primary"
  if currentMode == 1 then
    modeStr = "Short Break"
    modeColor = "success"
  elseif currentMode == 2 then
    modeStr = "Long Break"
    modeColor = "success"
  end

  local total = getDuration(currentMode)
  local progressVal = if total > 0 then remainingSeconds / total else 0

  local rows = {
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = modeStr, fontSize = 16, fontWeight = "bold", color = modeColor }),
      ui.label({ text = `Session: {completedSessions}`, fontSize = 11, color = "on_surface_variant" })
    }),

    ui.label({
      text = formatTime(remainingSeconds),
      fontSize = 32,
      fontWeight = "bold",
      color = "on_surface"
    }),

    ui.progress({
      progress = progressVal,
      fill = modeColor,
      width = 160,
      height = 6,
      radius = 3
    }),

    ui.row({ gap = 8 }, {
      ui.button({
        text = if running then "Pause" else "Start",
        variant = "primary",
        onClick = "toggleTimer"
      }),
      ui.button({
        text = "Skip",
        variant = "outline",
        onClick = "skipTimer"
      }),
      ui.button({
        text = "Reset",
        variant = "outline",
        onClick = "resetTimer"
      })
    }),

    ui.row({ gap = 6 }, {
      ui.button({
        text = "Work",
        variant = if currentMode == 0 then "primary" else "outline",
        onClick = "setModeWork"
      }),
      ui.button({
        text = "Short",
        variant = if currentMode == 1 then "primary" else "outline",
        onClick = "setModeShort"
      }),
      ui.button({
        text = "Long",
        variant = if currentMode == 2 then "primary" else "outline",
        onClick = "setModeLong"
      })
    }),

    ui.button({
      text = "Reset Cycle",
      variant = "flat",
      onClick = "resetAllTimer"
    })
  }

  desktopWidget.render(ui.column({ gap = 10, align = "center", padding = 16 }, rows))
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
  noctalia.setUpdateInterval(0)
  render()
end
