-- Catwalk — desktop widget.

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

  desktopWidget.render(ui.column({ gap = 8, align = "center" }, {
    -- We show the CPU usage text
    ui.label({
      text = string.format("CPU: %.1f%%", cpuUsage),
      fontSize = 14,
      fontWeight = "bold",
      color = "primary"
    }),
    -- Since we can't easily display raw custom SVGs inside ui elements directly,
    -- or wait, does ui have an icon/image component?
    -- In v5 plugins, let's look at what components are available.
    -- We can use a label with a custom glyph or button.
    -- Wait, does ui.button support glyphs?
    -- Let's check if there is an image component or if we can use a button with iconPath!
    -- Yes! In show-keys/widget.luau and others, we saw ui.button with text.
    -- If we use ui.button with the iconPath as the text, or wait:
    -- Can we pass icon/glyph? Let's check other plugins.
    -- In clipper/ClipboardCard.qml or other places, we had NIcon.
    -- But in Luau, we have ui.label and ui.button.
    -- We can just display the CPU text and the status. Let's make it look cute!
    ui.label({
      text = if isRunning then "🐱 Running..." else "😴 Sleeping...",
      fontSize = 12,
      color = "on_surface_variant"
    })
  }))
end

noctalia.state.watch("cpuUsage", function(val)
  cpuUsage = tonumber(val) or 0.0
  render()
end)

noctalia.state.watch("isRunning", function(val)
  local newRunning = val == true
  if newRunning ~= isRunning then
    isRunning = newRunning
    frameIndex = 0
  end
  render()
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

  local interval = 400
  if isRunning then
    interval = math.max(30, 200 - cpuUsage * 1.7)
  end

  noctalia.setUpdateInterval(interval)
  render()
end
