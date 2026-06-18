-- Parallax Wallpaper — background service.
local isActive = false
local function updateState() noctalia.state.set("isActive", isActive) end
noctalia.state.watch("command", function(cmd) if cmd == "toggle" then isActive = not isActive; updateState() end end)
noctalia.setUpdateInterval(0)
