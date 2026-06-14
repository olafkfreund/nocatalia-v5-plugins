-- Catwalk — bar widget.

local cpuUsage = 0.0
local isRunning = false
local frameIndex = 0
local basePath = nil

local function getFrames()
  if isRunning then
    return {
      "icons/my-active-0-symbolic.svg",
      "icons/my-active-1-symbolic.svg",
      "icons/my-active-2-symbolic.svg",
      "icons/my-active-3-symbolic.svg",
      "icons/my-active-4-symbolic.svg"
    }
  else
    return {
      "icons/my-idle-0-symbolic.svg",
      "icons/my-idle-1-symbolic.svg",
      "icons/my-idle-2-symbolic.svg",
      "icons/my-idle-3-symbolic.svg"
    }
  end
end

local function detectPath(onDone)
  local home = os.getenv("HOME") or "/tmp"
  local testPaths = {
    "catwalk",
    "/home/olafkfreund/Source/GitHub/nocatalia-v5-plugins/catwalk",
    `{home}/.local/share/noctalia/plugins/catwalk`,
    `{home}/.local/share/noctalia/plugins/catwalk-master`
  }
  
  local function tryIdx(idx)
    if idx > #testPaths then
      basePath = "catwalk"
      onDone()
      return
    end
    local p = testPaths[idx]
    noctalia.runAsync(`test -d '{p}'`, function(res)
      if res.exitCode == 0 then
        basePath = p
        onDone()
      else
        tryIdx(idx + 1)
      end
    end)
  end
  tryIdx(1)
end

local function render()
  if not basePath then return end
  local frames = getFrames()
  local f = frames[(frameIndex % #frames) + 1]
  local iconPath = `{basePath}/{f}`
  
  barWidget.setGlyph(iconPath)
  barWidget.setGlyphColor("primary")

  local statusKey = if isRunning then "tooltip.running" else "tooltip.sleeping"
  local statusText = noctalia.tr(statusKey) or (if isRunning then "Running" else "Sleeping")
  barWidget.setTooltip(`Catwalk\nStatus: {statusText}\nCPU Usage: {string.format("%.1f%%", cpuUsage)}`)
  barWidget.setText("")
end

function onClick()
  -- Open system monitor
  noctalia.runAsync("ghostty -e btop")
end

noctalia.state.watch("cpuUsage", function(val)
  cpuUsage = tonumber(val) or 0.0
end)

noctalia.state.watch("isRunning", function(val)
  local newRunning = val == true
  if newRunning ~= isRunning then
    isRunning = newRunning
    frameIndex = 0
  end
end)

function update()
  if not basePath then
    detectPath(function()
      noctalia.setUpdateInterval(100)
    end)
    return
  end

  local frames = getFrames()
  frameIndex = (frameIndex + 1) % #frames

  -- Set next animation interval based on CPU usage
  local interval = 400
  if isRunning then
    interval = math.max(30, 200 - cpuUsage * 1.7)
  end

  noctalia.setUpdateInterval(interval)
  render()
end
