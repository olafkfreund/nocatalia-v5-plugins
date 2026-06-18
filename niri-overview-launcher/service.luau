-- Niri Overview Launcher — background service.
-- Triggers the Niri overview mode via niri msg action.

local isOpen = false

local function toggle()
  noctalia.runAsync("niri msg action overview 2>/dev/null", function(res)
    isOpen = not isOpen
    noctalia.state.set("isOpen", isOpen)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    toggle()
  end
end)

noctalia.setUpdateInterval(0)
