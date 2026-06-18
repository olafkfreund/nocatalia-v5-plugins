-- Ramadan Iftar — background service.
-- Fetches Iftar and Suhoor times via the Aladhan API.

local iftarTime = ""
local suhoorTime = ""
local countdown = ""
local isRamadan = false
local configured = false

local function updateState()
  noctalia.state.set("iftarTime", iftarTime)
  noctalia.state.set("suhoorTime", suhoorTime)
  noctalia.state.set("countdown", countdown)
  noctalia.state.set("isRamadan", isRamadan)
  noctalia.state.set("configured", configured)
end

local function fetchTimes()
  local city = noctalia.getConfig("city") or ""
  local country = noctalia.getConfig("country") or ""
  local method = noctalia.getConfig("method") or 2

  if city == "" or country == "" then
    configured = false
    updateState()
    return
  end
  configured = true

  local url = "https://api.aladhan.com/v1/timingsByCity?city=" .. city
    .. "&country=" .. country
    .. "&method=" .. tostring(method)

  local cmd = 'curl -s -L --max-time 15 -H "User-Agent: Mozilla/5.0" "' .. url .. '" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    -- Extract Maghrib (Iftar) and Fajr (Suhoor) times
    local maghrib = text:match('"Maghrib":"([^"]+)"')
    local fajr = text:match('"Fajr":"([^"]+)"')
    if maghrib then iftarTime = maghrib end
    if fajr then suhoorTime = fajr end
    -- Check if Ramadan by looking at the month
    local month = text:match('"month":{"number":(%d+)')
    isRamadan = (month == "9") -- Ramadan is month 9 in Hijri
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    fetchTimes()
  end
end)

fetchTimes()

-- Refresh every hour
noctalia.setUpdateInterval(3600000)

function onUpdate()
  fetchTimes()
end
