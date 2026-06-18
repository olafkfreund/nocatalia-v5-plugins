-- Linux Wallpaper Engine Controller — background service.
local currentWallpaper = ""
local isRunning = false
local function updateState()
  noctalia.state.set("currentWallpaper", currentWallpaper)
  noctalia.state.set("isRunning", isRunning)
end
local function checkRunning()
  noctalia.runAsync("pgrep -x linux-wallpaperengine 2>/dev/null", function(res)
    isRunning = res.exitCode == 0
    updateState()
  end)
end
noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then checkRunning()
  elseif cmd == "stop" then
    noctalia.runAsync("pkill linux-wallpaperengine 2>/dev/null", function(res) isRunning = false; updateState() end)
  end
end)
checkRunning()
noctalia.setUpdateInterval(5000)
function onUpdate() checkRunning() end
