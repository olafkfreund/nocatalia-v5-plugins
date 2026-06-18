-- Video Wallpaper — background service.
local currentFile = ""
local isRunning = false
local function updateState()
  noctalia.state.set("currentFile", currentFile)
  noctalia.state.set("isRunning", isRunning)
end
local function checkRunning()
  local backend = noctalia.getConfig("activeBackend") or "mpvpaper"
  noctalia.runAsync("pgrep -x " .. backend .. " 2>/dev/null", function(res)
    isRunning = res.exitCode == 0
    updateState()
  end)
end
noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then checkRunning()
  elseif cmd == "stop" then
    local backend = noctalia.getConfig("activeBackend") or "mpvpaper"
    noctalia.runAsync("pkill " .. backend .. " 2>/dev/null", function(res) isRunning = false; updateState() end)
  end
end)
checkRunning()
noctalia.setUpdateInterval(5000)
function onUpdate() checkRunning() end
