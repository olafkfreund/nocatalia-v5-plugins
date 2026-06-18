-- Screenshot & Screen Record — background service.
-- Manages screenshots (grimblast/grim) and screen recording (wf-recorder).

local isRecording = false
local recordingPid = ""

local function updateState()
  noctalia.state.set("isRecording", isRecording)
end

local function checkRecording()
  noctalia.runAsync("pidof wf-recorder 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local pid = (res.stdout or res.body or ""):gsub("\n", "")
      isRecording = pid ~= ""
      recordingPid = pid
    else
      isRecording = false
      recordingPid = ""
    end
    updateState()
  end)
end

local function getPath(key, defaultPath)
  local p = noctalia.getConfig(key) or defaultPath
  return p:gsub("^~/", os.getenv("HOME") .. "/")
end

local function takeScreenshot(mode)
  local savePath = getPath("savePath", "~/Pictures/Screenshots")
  local editor = noctalia.getConfig("screenshotEditor") or "swappy"
  local filename = savePath .. "/screenshot-" .. os.date("%Y%m%d-%H%M%S") .. ".png"
  local cmd

  if mode == "area" then
    -- Try grimblast first, fall back to grim
    cmd = "grimblast --notify save area " .. filename .. " 2>/dev/null || grim -g \"$(slurp)\" " .. filename .. " 2>/dev/null"
  elseif mode == "window" then
    cmd = "grimblast --notify save active " .. filename .. " 2>/dev/null || grim " .. filename .. " 2>/dev/null"
  else
    cmd = "grimblast --notify save screen " .. filename .. " 2>/dev/null || grim " .. filename .. " 2>/dev/null"
  end

  if editor ~= "" and editor ~= "none" then
    cmd = cmd .. " && " .. editor .. " " .. filename .. " 2>/dev/null"
  end

  noctalia.runAsync("sh -c '" .. cmd .. "'", function(res)
    -- Screenshot done
  end)
end

local function toggleRecording()
  if isRecording then
    -- Stop recording
    noctalia.runAsync("kill " .. recordingPid .. " 2>/dev/null", function(res)
      isRecording = false
      recordingPid = ""
      updateState()
    end)
  else
    -- Start recording
    local savePath = getPath("recordingSavePath", "~/Videos")
    local filename = savePath .. "/recording-" .. os.date("%Y%m%d-%H%M%S") .. ".mp4"
    local cmd = "wf-recorder -f " .. filename .. " 2>/dev/null &"
    noctalia.runAsync("sh -c '" .. cmd .. "'", function(res)
      -- Check if started
      checkRecording()
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "screenshot" then
    takeScreenshot("screen")
  elseif cmd == "screenshot-area" then
    takeScreenshot("area")
  elseif cmd == "screenshot-window" then
    takeScreenshot("window")
  elseif cmd == "record" or cmd == "toggle-record" then
    toggleRecording()
  elseif cmd == "check" then
    checkRecording()
  end
end)

checkRecording()

noctalia.setUpdateInterval(2000)

function onUpdate()
  checkRecording()
end
