-- Niri Screensaver — background service.
-- Manages Niri screensaver via swayidle and swaylock.

local isLocked = false
local enabled = true

local function updateState()
  noctalia.state.set("isLocked", isLocked)
  noctalia.state.set("enabled", enabled)
end

local function checkLocked()
  noctalia.runAsync("pgrep swaylock 2>/dev/null", function(res)
    isLocked = res.exitCode == 0 and (res.stdout or res.body or "") ~= ""
    updateState()
  end)
end

local function lock()
  noctalia.runAsync("swaylock 2>/dev/null || loginctl lock-session 2>/dev/null", function(res)
    checkLocked()
  end)
end

local function unlock()
  noctalia.runAsync("pkill swaylock 2>/dev/null", function(res)
    checkLocked()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "lock" then
    lock()
  elseif cmd == "unlock" then
    unlock()
  elseif cmd == "toggle" then
    if isLocked then unlock() else lock() end
  elseif cmd == "refresh" then
    checkLocked()
  end
end)

enabled = noctalia.getConfig("enabled") ~= false
checkLocked()

noctalia.setUpdateInterval(5000)

function onUpdate()
  checkLocked()
end
