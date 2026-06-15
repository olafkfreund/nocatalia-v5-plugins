-- Screenshot — background service.
-- Detects compositor and executes screenshot commands.

noctalia.setUpdateInterval(0)

local desktop = (noctalia.getenv("XDG_CURRENT_DESKTOP") or ""):lower()
local isHyprland = desktop:find("hyprland") ~= nil or noctalia.commandExists("hyprctl")
local isNiri = desktop:find("niri") ~= nil or (noctalia.commandExists("niri") and not isHyprland)
local isSway = desktop:find("sway") ~= nil or (noctalia.commandExists("swaymsg") and not isHyprland and not isNiri)

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" or cmd.action ~= "take" then return end
  
  local mode = cmd.mode or noctalia.getConfig("mode") or "region"
  local args = {}
  
  if isHyprland then
    if mode == "active-window" then
      args = { "hyprshot", "-m", "window", "-m", "active", "--clipboard-only", "--silent" }
    elseif mode == "active-screen" or mode == "screen" then
      args = { "hyprshot", "-m", "output", "-m", "active", "--clipboard-only", "--silent" }
    else
      args = { "hyprshot", "--freeze", "--clipboard-only", "--mode", "region", "--silent" }
    end
  elseif isNiri then
    args = { "niri", "msg", "action", "screenshot" }
  elseif isSway then
    if mode == "screen" or mode == "active-screen" then
      args = { "grimshot", "copy", "output" }
    elseif mode == "window" or mode == "active-window" then
      args = { "grimshot", "copy", "active" }
    else
      args = { "grimshot", "copy", "area" }
    end
  else
    noctalia.notifyError(
      noctalia.tr("notification.title") or "Screenshot", 
      noctalia.tr("notification.unsupported-compositor") or "Screenshots are not supported in this compositor."
    )
    return
  end
  
  local cmdStr = table.concat(args, " ")
  noctalia.runAsync(cmdStr, function(res)
    if res.exitCode == 0 then
      noctalia.notify(
        noctalia.tr("notification.title") or "Screenshot", 
        noctalia.tr("notification.success") or "Captured and copied to clipboard"
      )
    else
      noctalia.notifyError(
        noctalia.tr("notification.title") or "Screenshot", 
        `Failed: {res.stderr or res.body or "Unknown error"}`
      )
    end
  end)
end)

function update()
end
