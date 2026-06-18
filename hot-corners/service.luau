-- Hot Corners — background service.
-- Monitors cursor position and triggers actions at screen corners.

local enabled = true
local triggeredCorner = ""

local function updateState()
  noctalia.state.set("enabled", enabled)
  noctalia.state.set("triggeredCorner", triggeredCorner)
end

local function getScreenSize()
  noctalia.runAsync("xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' | head -1", function(res)
    local dims = (res.stdout or res.body or ""):gsub("\n", "")
    local w, h = dims:match("(%d+)x(%d+)")
    noctalia.state.set("screenWidth", w or "1920")
    noctalia.state.set("screenHeight", h or "1080")
  end)
end

local function checkCorner(x, y, screenW, screenH)
  local delay = tonumber(noctalia.getConfig("triggerDelay")) or 200
  local corner = ""
  local cmd = ""

  if x == 0 and y == 0 then
    corner = "topLeft"
    cmd = noctalia.getConfig("topLeft") or ""
  elseif x >= screenW - 1 and y == 0 then
    corner = "topRight"
    cmd = noctalia.getConfig("topRight") or ""
  elseif x == 0 and y >= screenH - 1 then
    corner = "bottomLeft"
    cmd = noctalia.getConfig("bottomLeft") or ""
  elseif x >= screenW - 1 and y >= screenH - 1 then
    corner = "bottomRight"
    cmd = noctalia.getConfig("bottomRight") or ""
  end

  if corner ~= "" and cmd ~= "" and corner ~= triggeredCorner then
    triggeredCorner = corner
    noctalia.runAsync(cmd .. " 2>/dev/null", function(res)
    end)
    updateState()
  elseif corner == "" then
    triggeredCorner = ""
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    enabled = not enabled
    updateState()
  end
end)

getScreenSize()

noctalia.setUpdateInterval(0)
