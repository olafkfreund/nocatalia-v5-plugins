-- Screen Toolkit — background service.
local lastColor = ""
local function updateState() noctalia.state.set("lastColor", lastColor) end
local function pickColor()
  noctalia.runAsync("hyprpicker -a 2>/dev/null || xcolor 2>/dev/null || gpick 2>/dev/null", function(res)
    local color = (res.stdout or res.body or ""):gsub("\n","")
    if color ~= "" then lastColor = color; updateState() end
  end)
end
noctalia.state.watch("command", function(cmd) if cmd == "pick-color" then pickColor() end end)
noctalia.setUpdateInterval(0)
