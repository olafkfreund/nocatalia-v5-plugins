-- Pomodoro — background service.

noctalia.setUpdateInterval(1000)

local modeWork = 0
local modeShortBreak = 1
local modeLongBreak = 2

local running = false
local currentMode = modeWork
local remainingSeconds = 0
local completedSessions = 0
local alarmPlaying = false
local resolvedAlarmPath = "alarm.mp3"

local function detectAlarmPath()
  local home = noctalia.getenv("HOME") or "/tmp"
  local testPaths = {
    "pomodoro/alarm.mp3",
    `{home}/.local/share/noctalia/plugins/pomodoro/alarm.mp3`,
    `{home}/.local/share/noctalia/plugins/pomodoro-master/alarm.mp3`
  }
  local function tryIdx(idx)
    if idx > #testPaths then
      resolvedAlarmPath = "alarm.mp3"
      return
    end
    local p = testPaths[idx]
    noctalia.runAsync(`test -f '{p}'`, function(res)
      if res.exitCode == 0 then
        resolvedAlarmPath = p
      else
        tryIdx(idx + 1)
      end
    end)
  end
  tryIdx(1)
end

detectAlarmPath()

local function getDuration(mode)
  if mode == modeWork then
    return (tonumber(noctalia.getConfig("workDuration")) or 25) * 60
  elseif mode == modeShortBreak then
    return (tonumber(noctalia.getConfig("shortBreakDuration")) or 5) * 60
  elseif mode == modeLongBreak then
    return (tonumber(noctalia.getConfig("longBreakDuration")) or 15) * 60
  end
  return 25 * 60
end

local function stopAlarm()
  if alarmPlaying then
    noctalia.runAsync(`pkill -f 'pw-play.*{resolvedAlarmPath}'`)
    alarmPlaying = false
    noctalia.state.set("alarmPlaying", false)
  end
end

local function playAlarm()
  local playSound = noctalia.getConfig("playSound") ~= false
  if playSound then
    stopAlarm()
    alarmPlaying = true
    noctalia.state.set("alarmPlaying", true)
    noctalia.runAsync(`pw-play '{resolvedAlarmPath}'`)
    
    -- Auto stop alarm after 30 seconds
    noctalia.runAsync("sleep 30 && pkill -f 'pw-play.*" .. resolvedAlarmPath .. "'", function()
      alarmPlaying = false
      noctalia.state.set("alarmPlaying", false)
    end)
  end
end

local function advancePhase()
  local sessionsBeforeLongBreak = tonumber(noctalia.getConfig("sessionsBeforeLongBreak")) or 4
  
  if currentMode == modeWork then
    if completedSessions + 1 >= sessionsBeforeLongBreak then
      currentMode = modeLongBreak
    else
      currentMode = modeShortBreak
    end
  else
    if currentMode == modeLongBreak then
      completedSessions = 0
    else
      completedSessions = completedSessions + 1
    end
    currentMode = modeWork
  end
  
  remainingSeconds = getDuration(currentMode)
  noctalia.state.set("mode", currentMode)
  noctalia.state.set("remainingSeconds", remainingSeconds)
  noctalia.state.set("completedSessions", completedSessions)
end

local function pomodoroFinished()
  running = false
  noctalia.state.set("running", false)
  
  local title = noctalia.tr("toast.title") or "Pomodoro"
  local msg = ""
  local autoStart = false
  
  if currentMode == modeWork then
    msg = noctalia.tr("toast.work-finished") or "Work session complete! Time for a break."
    autoStart = noctalia.getConfig("autoStartBreaks") == true
  elseif currentMode == modeLongBreak then
    msg = noctalia.tr("toast.long-break-finished") or "Long break over! Ready for a new cycle?"
    autoStart = noctalia.getConfig("autoStartWork") == true
  else
    msg = noctalia.tr("toast.break-finished") or "Break over! Ready to focus?"
    autoStart = noctalia.getConfig("autoStartWork") == true
  end
  
  noctalia.notify(title, msg)
  playAlarm()
  advancePhase()
  
  if autoStart then
    running = true
    noctalia.state.set("running", true)
  end
end

-- Initialize state
noctalia.state.set("running", false)
noctalia.state.set("mode", modeWork)
noctalia.state.set("completedSessions", 0)

function update()
  -- If remainingSeconds is not initialized, set it
  if remainingSeconds <= 0 then
    remainingSeconds = getDuration(currentMode)
    noctalia.state.set("remainingSeconds", remainingSeconds)
  end

  if running then
    remainingSeconds = remainingSeconds - 1
    if remainingSeconds <= 0 then
      pomodoroFinished()
    else
      noctalia.state.set("remainingSeconds", remainingSeconds)
    end
  end
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  local action = cmd.action
  
  stopAlarm()
  
  if action == "start" then
    running = true
    noctalia.state.set("running", true)
    
  elseif action == "pause" then
    running = false
    noctalia.state.set("running", false)
    
  elseif action == "reset" then
    running = false
    remainingSeconds = getDuration(currentMode)
    noctalia.state.set("running", false)
    noctalia.state.set("remainingSeconds", remainingSeconds)
    
  elseif action == "reset_all" then
    running = false
    currentMode = modeWork
    completedSessions = 0
    remainingSeconds = getDuration(currentMode)
    
    noctalia.state.set("running", false)
    noctalia.state.set("mode", currentMode)
    noctalia.state.set("completedSessions", completedSessions)
    noctalia.state.set("remainingSeconds", remainingSeconds)
    
  elseif action == "skip" then
    running = false
    noctalia.state.set("running", false)
    advancePhase()
    
  elseif action == "stop_alarm" then
    -- Already stopped at the top of the command watch
    
  elseif action == "set_mode" then
    local newMode = tonumber(cmd.mode)
    if newMode then
      running = false
      currentMode = newMode
      remainingSeconds = getDuration(currentMode)
      
      noctalia.state.set("running", false)
      noctalia.state.set("mode", currentMode)
      noctalia.state.set("remainingSeconds", remainingSeconds)
    end
  end
end)
