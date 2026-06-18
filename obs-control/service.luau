-- OBS Control — background service.
-- Monitors OBS Studio status via pidof and obs-cmd (if available).

local obsRunning = false
local isRecording = false
local isStreaming = false
local recordingTime = ""

local function updateState()
  noctalia.state.set("obsRunning", obsRunning)
  noctalia.state.set("isRecording", isRecording)
  noctalia.state.set("isStreaming", isStreaming)
  noctalia.state.set("recordingTime", recordingTime)
end

local function refresh()
  -- Check if OBS is running
  noctalia.runAsync("pidof obs obs-studio 2>/dev/null", function(res)
    obsRunning = res.exitCode == 0 and (res.stdout or res.body or "") ~= ""
    if not obsRunning then
      isRecording = false
      isStreaming = false
      recordingTime = ""
      updateState()
      return
    end
    -- Try obs-cmd if available for status
    noctalia.runAsync("obs-cmd recording status 2>/dev/null", function(recRes)
      local text = (recRes.stdout or recRes.body or ""):lower()
      isRecording = text:match("active") ~= nil or text:match("recording") ~= nil
      -- Try to get time
      local t = text:match("(%d+:%d+:%d+)")
      recordingTime = t or ""
      updateState()
    end)
    noctalia.runAsync("obs-cmd streaming status 2>/dev/null", function(strRes)
      local text = (strRes.stdout or strRes.body or ""):lower()
      isStreaming = text:match("active") ~= nil or text:match("streaming") ~= nil
      updateState()
    end)
  end)
end

local function startObs()
  noctalia.runAsync("obs --minimize-to-tray 2>/dev/null &", function(res)
    -- Give OBS time to start
    refresh()
  end)
end

local function toggleRecord()
  if isRecording then
    noctalia.runAsync("obs-cmd recording stop 2>/dev/null", function(res)
      refresh()
    end)
  else
    noctalia.runAsync("obs-cmd recording start 2>/dev/null", function(res)
      refresh()
    end)
  end
end

local function toggleStream()
  if isStreaming then
    noctalia.runAsync("obs-cmd streaming stop 2>/dev/null", function(res)
      refresh()
    end)
  else
    noctalia.runAsync("obs-cmd streaming start 2>/dev/null", function(res)
      refresh()
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "toggle-record" then
    toggleRecord()
  elseif cmd == "toggle-stream" then
    toggleStream()
  elseif cmd == "start-obs" then
    startObs()
  end
end)

refresh()

local interval = tonumber(noctalia.getConfig("pollIntervalMs")) or 2500
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
