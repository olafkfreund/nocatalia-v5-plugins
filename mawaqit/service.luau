-- Mawaqit — background service.
-- Fetches prayer times via Aladhan API and tracks next prayer.

local prayers = {}
local nextPrayer = ""
local nextPrayerTime = ""
local countdown = ""

local PRAYER_NAMES = {"Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"}

local function timeToMinutes(timeStr)
  if not timeStr then return 0 end
  local h, m = timeStr:match("^(%d+):(%d+)")
  if h and m then
    return tonumber(h) * 60 + tonumber(m)
  end
  return 0
end

local function updateState()
  noctalia.state.set("nextPrayer", nextPrayer)
  noctalia.state.set("nextPrayerTime", nextPrayerTime)
  noctalia.state.set("countdown", countdown)
end

local function updateCountdown()
  if nextPrayerTime == "" then return end
  local now = os.date("*t")
  local nowMins = now.hour * 60 + now.min
  local targetMins = timeToMinutes(nextPrayerTime)
  local diff = targetMins - nowMins
  if diff < 0 then diff = diff + 24 * 60 end
  local h = math.floor(diff / 60)
  local m = diff % 60
  if h > 0 then
    countdown = h .. "h " .. m .. "m"
  else
    countdown = m .. "m"
  end
  updateState()
end

local function findNextPrayer()
  if #prayers == 0 then return end
  local now = os.date("*t")
  local nowMins = now.hour * 60 + now.min
  local found = false
  for _, prayer in ipairs(prayers) do
    local pMins = timeToMinutes(prayer.time)
    if pMins > nowMins then
      nextPrayer = prayer.name
      nextPrayerTime = prayer.time
      found = true
      break
    end
  end
  if not found and #prayers > 0 then
    nextPrayer = prayers[1].name
    nextPrayerTime = prayers[1].time
  end
  updateCountdown()
end

local function fetchTimes()
  local city = noctalia.getConfig("city") or "London"
  local country = noctalia.getConfig("country") or "UK"
  local method = noctalia.getConfig("method") or 3
  local school = noctalia.getConfig("school") or 0

  local url = "https://api.aladhan.com/v1/timingsByCity?city=" .. city
    .. "&country=" .. country
    .. "&method=" .. tostring(method)
    .. "&school=" .. tostring(school)

  local cmd = 'curl -s -L --max-time 15 -H "User-Agent: Mozilla/5.0" "' .. url .. '" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    -- Parse prayer times
    local timings = {}
    for name in text:gmatch('"([^"]+)":"(%d+:%d+)"') do
      -- match only known prayer names
    end
    -- Extract each prayer time
    local prayerData = {}
    for _, pname in ipairs(PRAYER_NAMES) do
      local t = text:match('"' .. pname .. '":"(%d+:%d+)"')
      if t then
        prayerData[#prayerData + 1] = {name = pname, time = t}
      end
    end
    prayers = prayerData
    findNextPrayer()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    fetchTimes()
  elseif cmd == "updateCountdown" then
    updateCountdown()
  end
end)

fetchTimes()

-- Update countdown every minute, prayer times every hour
noctalia.setUpdateInterval(60000)

function onUpdate()
  updateCountdown()
  -- Re-fetch prayer times once per day at midnight (when minutes are near 0)
  local now = os.date("*t")
  if now.hour == 0 and now.min < 2 then
    fetchTimes()
  end
end
