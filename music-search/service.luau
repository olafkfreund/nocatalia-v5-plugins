-- Music Search — background service.
local isOpen = false
noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    isOpen = not isOpen
    noctalia.state.set("isOpen", isOpen)
  end
end)
noctalia.setUpdateInterval(0)
