-- Model Usage — background service.
local totalCost = "0.00"
local totalTokens = 0
local currentProvider = ""
local function updateState()
  noctalia.state.set("totalCost", totalCost)
  noctalia.state.set("totalTokens", totalTokens)
  noctalia.state.set("currentProvider", currentProvider)
end
noctalia.state.watch("command", function(cmd) if cmd == "refresh" then updateState() end end)
updateState()
noctalia.setUpdateInterval(0)
