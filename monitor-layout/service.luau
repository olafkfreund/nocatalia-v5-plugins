-- Monitor Layout — background service.
-- Manages monitor layout configurations.

local monitors = {}
local monitorCount = 0
local backend = "auto"

local function updateState()
  noctalia.state.set("monitorCount", monitorCount)
  noctalia.state.set("backend", backend)
end

local function detectBackend()
  local cfg = noctalia.getConfig("backend") or "auto"
  if cfg ~= "auto" then
    backend = cfg
    return
  end
  if os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then
    backend = "hyprland"
  elseif os.getenv("SWAYSOCK") then
    backend = "sway"
  else
    backend = "unknown"
  end
end

local function getMonitors()
  detectBackend()
  local hyprctl = noctalia.getConfig("hyprctlCommand") or "hyprctl"
  local swaymsg = noctalia.getConfig("swayCommand") or "swaymsg"

  if backend == "hyprland" then
    noctalia.runAsync(hyprctl .. " monitors -j 2>/dev/null", function(res)
      monitors = {}
      for name in (res.stdout or res.body or ""):gmatch('"name":"([^"]+)"') do
        monitors[#monitors + 1] = name
      end
      monitorCount = #monitors
      updateState()
    end)
  elseif backend == "sway" then
    noctalia.runAsync(swaymsg .. " -t get_outputs 2>/dev/null | python3 -c \"import sys,json; [print(o.get('name','?')) for o in json.load(sys.stdin)]\" 2>/dev/null", function(res)
      monitors = {}
      for name in (res.stdout or res.body or ""):gmatch("[^\n]+") do
        if name ~= "" then monitors[#monitors + 1] = name end
      end
      monitorCount = #monitors
      updateState()
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    getMonitors()
  end
end)

getMonitors()

noctalia.setUpdateInterval(0)
