-- Hyprland Steam Overlay — background service.
local isOpen = false
local steamRunning = false
local function updateState()
  noctalia.state.set("isOpen", isOpen)
  noctalia.state.set("steamRunning", steamRunning)
end
local function checkSteam()
  noctalia.runAsync("pgrep -x steam 2>/dev/null || pgrep -x Steam 2>/dev/null", function(res)
    steamRunning = res.exitCode == 0
    updateState()
  end)
end
local function toggle()
  isOpen = not isOpen
  updateState()
end
noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then toggle()
  elseif cmd == "refresh" then checkSteam() end
end)
if noctalia.getConfig("autoLaunchSteam") == true then
  noctalia.runAsync("steam 2>/dev/null &", function(res) end)
end
checkSteam()
noctalia.setUpdateInterval(10000)
function onUpdate() checkSteam() end
