-- MPD — background service.
-- Polls MPD status via `mpc` and provides playback controls.

local title = ""
local artist = ""
local status = "stopped"
local shuffle = false
local mpcAvailable = false

local function updateState()
  noctalia.state.set("title", title)
  noctalia.state.set("artist", artist)
  noctalia.state.set("status", status)
  noctalia.state.set("shuffle", shuffle)
  noctalia.state.set("mpcAvailable", mpcAvailable)
end

local function refresh()
  noctalia.runAsync("mpc status 2>/dev/null", function(res)
    mpcAvailable = (res.exitCode == 0)
    if not mpcAvailable then
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    -- Parse status line: [playing] or [paused] or (nothing for stopped)
    local st = text:match("%[([%a]+)%]")
    if st then
      status = st
    else
      status = "stopped"
    end
    -- Parse shuffle from options line
    shuffle = text:match("random: on") ~= nil
    updateState()
  end)

  noctalia.runAsync("mpc current -f '%title% - %artist%' 2>/dev/null", function(res)
    if res.exitCode ~= 0 then return end
    local text = (res.stdout or res.body or ""):gsub("\n", "")
    local t, a = text:match("^(.+) %- (.+)$")
    if t and a then
      title = t
      artist = a
    else
      title = text
      artist = ""
    end
    updateState()
  end)
end

local function runMpc(cmd)
  noctalia.runAsync("mpc " .. cmd .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function executeAction(action)
  if action == "none" or action == "" then return end
  if action == "next" then runMpc("next")
  elseif action == "prev" then runMpc("prev")
  elseif action == "toggle" then runMpc("toggle")
  elseif action == "stop" then runMpc("stop")
  elseif action == "shuffle" then
    local shuffleStops = noctalia.getConfig("shuffleStopsPlayback") ~= false
    if shuffleStops and status == "playing" then
      runMpc("stop && mpc random toggle")
    else
      runMpc("random toggle")
    end
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd then
    executeAction(cmd)
  end
end)

refresh()

noctalia.setUpdateInterval(3000)

function onUpdate()
  refresh()
end
