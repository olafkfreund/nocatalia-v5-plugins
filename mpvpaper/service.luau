-- mpvpaper — background service.
-- Controls mpvpaper animated wallpaper via mpv IPC socket.

local currentWallpaper = ""
local isPlaying = true
local isPaused = false

local function updateState()
  noctalia.state.set("currentWallpaper", currentWallpaper)
  noctalia.state.set("isPlaying", isPlaying)
  noctalia.state.set("isPaused", isPaused)
end

local function mpvCmd(cmd)
  local socket = noctalia.getConfig("mpvSocket") or "/tmp/mpv-socket"
  local json = '{"command": ' .. cmd .. '}'
  noctalia.runAsync('echo \'' .. json .. '\' | socat - "' .. socket .. '" 2>/dev/null', function(res)
    updateState()
  end)
end

local function togglePause()
  mpvCmd('["cycle", "pause"]')
  isPaused = not isPaused
  updateState()
end

local function nextWallpaper()
  mpvCmd('["playlist-next"]')
end

local function prevWallpaper()
  mpvCmd('["playlist-prev"]')
end

local function getCurrentFile()
  local socket = noctalia.getConfig("mpvSocket") or "/tmp/mpv-socket"
  noctalia.runAsync('echo \'{"command": ["get_property", "filename"]}\' | socat - "' .. socket .. '" 2>/dev/null', function(res)
    local text = res.stdout or res.body or ""
    local filename = text:match('"data":"([^"]+)"')
    if filename then
      currentWallpaper = filename
      updateState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle-pause" then
    togglePause()
  elseif cmd == "next" then
    nextWallpaper()
  elseif cmd == "prev" then
    prevWallpaper()
  elseif cmd == "refresh" then
    getCurrentFile()
  end
end)

getCurrentFile()

noctalia.setUpdateInterval(5000)

function onUpdate()
  getCurrentFile()
end
