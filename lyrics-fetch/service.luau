-- Lyrics Fetch — background service.
-- Fetches song lyrics via playerctl metadata and LRCLIB API.

local currentTitle = ""
local currentArtist = ""
local currentLyrics = ""
local isPlaying = false

local function updateState()
  noctalia.state.set("currentTitle", currentTitle)
  noctalia.state.set("currentArtist", currentArtist)
  noctalia.state.set("currentLyrics", currentLyrics)
  noctalia.state.set("isPlaying", isPlaying)
end

local lastTrack = ""

local function fetchLyrics(title, artist)
  local trackKey = title .. " - " .. artist
  if trackKey == lastTrack or title == "" then return end
  lastTrack = trackKey

  local titleEnc = title:gsub(" ", "+"):gsub("([^%w%+])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  local artistEnc = artist:gsub(" ", "+"):gsub("([^%w%+])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)

  local url = "https://lrclib.net/api/get?artist_name=" .. artistEnc .. "&track_name=" .. titleEnc
  local cmd = 'curl -s --max-time 10 "' .. url .. '" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local text = res.stdout or res.body or ""
      local synced = text:match('"syncedLyrics":"(.-)"[,}]')
      local plain = text:match('"plainLyrics":"(.-)"[,}]')
      local lyrics = synced or plain or ""
      -- Unescape JSON string
      lyrics = lyrics:gsub("\\n", "\n"):gsub('\\"', '"'):gsub("\\\\", "\\")
      currentLyrics = lyrics
      updateState()
    end
  end)
end

local function refresh()
  noctalia.runAsync("playerctl status 2>/dev/null", function(res)
    local status = (res.stdout or res.body or ""):gsub("\n", "")
    isPlaying = status == "Playing"
    if not isPlaying then
      updateState()
      return
    end
    noctalia.runAsync("playerctl metadata --format '{{ xesam:title }}|||{{ xesam:artist }}' 2>/dev/null", function(metaRes)
      local meta = (metaRes.stdout or metaRes.body or ""):gsub("\n", "")
      local title, artist = meta:match("^(.-)|||(.*)$")
      currentTitle = title or meta
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

noctalia.setUpdateInterval(3000)

function onUpdate()
  refresh()
end
