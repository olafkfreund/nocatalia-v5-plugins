-- Wallcards — background service.
local cardCount = 0
local function updateState() noctalia.state.set("cardCount", cardCount) end
noctalia.state.watch("command", function(cmd) if cmd == "refresh" then updateState() end end)
noctalia.setUpdateInterval(0)
