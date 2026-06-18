-- DeskVis — background service.
local isActive = false
local function updateState() noctalia.state.set("isActive", isActive) end
local function toggleVisualizer()
  isActive = not isActive
  updateState()
end
noctalia.state.watch("command", function(cmd) if cmd == "toggle" then toggleVisualizer() end end)
noctalia.setUpdateInterval(0)
