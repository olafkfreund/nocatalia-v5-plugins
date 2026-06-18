-- Hyprland Visual Editor — background service.
local borderSize = 2
local isActive = true
local function applyBorderSize(size)
  noctalia.runAsync("hyprctl keyword general:border_size " .. tostring(size) .. " 2>/dev/null", function(res) end)
end
local function getCurrentSettings()
  noctalia.runAsync("hyprctl getoption general:border_size -j 2>/dev/null", function(res)
    local text = res.stdout or res.body or ""
    local val = text:match('"int":(%d+)')
    if val then
      borderSize = tonumber(val) or 2
      noctalia.state.set("borderSize", borderSize)
    end
  end)
end
noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then getCurrentSettings()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "set-border" then
      borderSize = tonumber(arg) or 2
      applyBorderSize(borderSize)
      noctalia.state.set("borderSize", borderSize)
    end
  end
end)
isActive = noctalia.getConfig("isSystemActive") ~= false
borderSize = tonumber(noctalia.getConfig("borderSize")) or 2
noctalia.state.set("isActive", isActive)
noctalia.state.set("borderSize", borderSize)
getCurrentSettings()
noctalia.setUpdateInterval(0)
