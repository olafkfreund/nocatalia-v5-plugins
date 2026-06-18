-- Niri Auto Tile — background service.
-- Monitors Niri workspace window count and adjusts tiling.

local enabled = true
local windowCount = 0
local tileMode = "auto"

local function updateState()
  noctalia.state.set("enabled", enabled)
  noctalia.state.set("windowCount", windowCount)
  noctalia.state.set("tileMode", tileMode)
end

local function applyTiling()
  if not enabled then return end
  local maxVisible = tonumber(noctalia.getConfig("maxVisible")) or 4
  -- Get focused workspace window count
  noctalia.runAsync("niri msg -j focused-output 2>/dev/null", function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    -- Parse window/column count from workspace info
    local count = 0
    for _ in text:gmatch('"windows":') do count = count + 1 end
    windowCount = count
    if count <= maxVisible then
      tileMode = "tiled"
    else
      tileMode = "stacked"
    end
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    enabled = not enabled
    updateState()
  elseif cmd == "refresh" then
    applyTiling()
  end
end)

enabled = noctalia.getConfig("enabled") ~= false
applyTiling()

noctalia.setUpdateInterval(1000)

function onUpdate()
  applyTiling()
end
