-- Saved Desktop Widgets — background service.
local saveFile = os.getenv("HOME") .. "/.local/share/noctalia/desktop-widgets.json"
local widgetCount = 0
local function updateState() noctalia.state.set("widgetCount", widgetCount) end
local function load()
  noctalia.runAsync("cat " .. saveFile .. " 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(len(d.get('widgets',[])))\" 2>/dev/null", function(res)
    widgetCount = tonumber((res.stdout or res.body or "0"):gsub("\n","")) or 0
    updateState()
  end)
end
noctalia.state.watch("command", function(cmd) if cmd == "refresh" then load() end end)
load()
noctalia.setUpdateInterval(0)
