-- Workspace Overview — background service.
-- Detects compositor and triggers overview/expose mode.

local isOpen = false

local function updateState()
  noctalia.state.set("isOpen", isOpen)
end

local function detectCompositor()
  local env = os.getenv("XDG_CURRENT_DESKTOP") or os.getenv("HYPRLAND_INSTANCE_SIGNATURE") and "Hyprland" or ""
  if os.getenv("NIRI_SOCKET") then return "niri"
  elseif os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then return "hyprland"
  elseif os.getenv("SWAYSOCK") then return "sway"
  end
  return "unknown"
end

local function toggleOverview()
  local compositor = detectCompositor()
  if compositor == "hyprland" then
    noctalia.runAsync("hyprctl dispatch overview 2>/dev/null || hyprctl dispatch toggleoverview 2>/dev/null", function(res)
      isOpen = not isOpen
      updateState()
    end)
  elseif compositor == "niri" then
    noctalia.runAsync("niri msg action overview 2>/dev/null", function(res)
      isOpen = not isOpen
      updateState()
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    toggleOverview()
  elseif cmd == "close" then
    isOpen = false
    updateState()
  end
end)

noctalia.setUpdateInterval(0)
