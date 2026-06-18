-- Mirror Mirror — background service.
-- Detects compositor and mirrors display output.

local isMirrored = false
local monitors = {}

local function updateState()
  noctalia.state.set("isMirrored", isMirrored)
  noctalia.state.set("monitorCount", #monitors)
end

local function getMonitors()
  -- Try to detect compositor
  if os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then
    noctalia.runAsync("hyprctl monitors -j 2>/dev/null", function(res)
      local text = res.stdout or res.body or ""
      monitors = {}
      for name in text:gmatch('"name":"([^"]+)"') do
        monitors[#monitors + 1] = name
      end
      updateState()
    end)
  elseif os.getenv("SWAYSOCK") then
    noctalia.runAsync("swaymsg -t get_outputs 2>/dev/null | python3 -c \"import sys,json; [print(o['name']) for o in json.load(sys.stdin)]\" 2>/dev/null", function(res)
      monitors = {}
      for name in (res.stdout or res.body or ""):gmatch("[^\n]+") do
        if name ~= "" then monitors[#monitors + 1] = name end
      end
      updateState()
    end)
  end
end

local function toggleMirror(source, target)
  if os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then
    local cmd = isMirrored and
      ('hyprctl keyword monitor ' .. (target or monitors[2] or "") .. ',preferred,auto,1') or
      ('hyprctl keyword monitor ' .. (target or monitors[2] or "") .. ',preferred,auto,1,mirror,' .. (source or monitors[1] or ""))
    noctalia.runAsync(cmd .. " 2>/dev/null", function(res)
      isMirrored = not isMirrored
      updateState()
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    getMonitors()
  elseif cmd == "toggle" then
    toggleMirror(monitors[1], monitors[2])
  end
end)

getMonitors()

noctalia.setUpdateInterval(0)
