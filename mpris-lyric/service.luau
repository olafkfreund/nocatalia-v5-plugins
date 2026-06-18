-- MPRIS Lyric — background service.
-- Fetches current track info and lyrics via playerctl and LRCLIB API.

local currentTitle = ""
local currentArtist = ""
local currentLyric = ""
local isPlaying = false
local position = 0

local function updateState()
  noctalia.state.set("currentTitle", currentTitle)
  noctalia.state.set("currentArtist", currentArtist)
  noctalia.state.set("currentLyric", currentLyric)
  noctalia.state.set("isPlaying", isPlaying)
end

local function getPlayerArg()
  local player = noctalia.getConfig("playerName") or ""
  if player ~= "" then
    return "-p " .. player .. " "
  end
  return ""
end

local lastTrack = ""

local function fetchLyrics(title, artist)
  if title == "" then return end
  local trackKey = artist .. " - " .. title
  if trackKey == lastTrack then return end
  lastTrack = trackKey

  local url = "https://lrclib.net/api/get?artist_name=" .. artist:gsub(" ", "+") .. "&track_name=" .. title:gsub(" ", "+")
  local cmd = 'curl -s --max-time 10 "' .. url .. '" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local text = res.stdout or res.body or ""
      -- Extract syncedLyrics or plainLyrics
      local synced = text:match('"syncedLyrics":"([^"]+)"')
      local plain = text:match('"plainLyrics":"([^"]+)"')
      if synced and synced ~= "" then
        -- Store the full lyrics for position-based display
        noctalia.state.set("fullLyrics", synced)
        currentLyric = "♪ " .. title
      elseif plain and plain ~= "" then
        currentLyric = "♪ " .. title
        noctalia.state.set("fullLyrics", plain)
      else
        currentLyric = "♪ " .. title .. " - " .. artist
      end
      updateState()
    end
  end)
end

local function refresh()
  local playerArg = getPlayerArg()
  noctalia.runAsync("playerctl " .. playerArg .. "status 2>/dev/null", function(res)
    local status = (res.stdout or res.body or ""):gsub("\n", "")
    isPlaying = status == "Playing"

    if not isPlaying then
      currentLyric = ""
      updateState()
      return
    end

    noctalia.runAsync("playerctl " .. playerArg .. "metadata --format '{{title}}|{{artist}}' 2>/dev/null", function(metaRes)
      local meta = (metaRes.stdout or metaRes.body or ""):gsub("\n", "")
      local title, artist = meta:match("^([^|]+)|(.*)$")
      if not title or title == "" then
        title = meta
        artist = ""
      end
      currentTitle = title or ""
      currentArtist = artist or ""
      updateState()
      fetchLyrics(currentTitle, currentArtist)
    end)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  end
end)

refresh()

local interval = tonumber(noctalia.getConfig("updateInterval")) or 2000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
