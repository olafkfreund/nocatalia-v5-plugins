-- World Clock Service
-- Rotates through enabled timezones and publishes currentTime / currentCity / currentTimezone
-- to noctalia.state every second.

-- Built-in default timezones (used when the setting is empty)
local DEFAULT_TIMEZONES = {
  { name = "New York", timezone = "America/New_York", enabled = true },
  { name = "London",   timezone = "Europe/London",    enabled = true },
  { name = "Tokyo",    timezone = "Asia/Tokyo",        enabled = true },
}

-- State
local currentIndex = 1        -- 1-based index into enabledTimezones
local elapsedMs   = 0         -- milliseconds since last rotation
local enabledTimezones = {}    -- populated on init / config change

-- Map timeFormat setting values to date(1) format strings
local function toDateFormat(fmt)
  if fmt == "HH:mm:ss" then
    return "+%H:%M:%S"
  elseif fmt == "h:mm A" then
    return "+%I:%M %p"
  elseif fmt == "h:mm:ss A" then
    return "+%I:%M:%S %p"
  else
    -- default: "HH:mm"
    return "+%H:%M"
  end
end

-- Parse the timezones JSON setting.
-- Returns the array of enabled timezone entries, or DEFAULT_TIMEZONES if
-- the setting is empty or unparseable.
local function loadTimezones()
  local raw = noctalia.settings.get("timezones") or ""
  if raw == "" then
    return DEFAULT_TIMEZONES
  end

  local ok, parsed = pcall(function()
    return noctalia.json.decode(raw)
  end)

  if ok and type(parsed) == "table" then
    return parsed
  end

  -- Fallback to defaults on parse error
  noctalia.log.warn("world-clock: failed to parse timezones setting, using defaults")
  return DEFAULT_TIMEZONES
end

-- Rebuild the enabled-timezones list from the full list
local function rebuildEnabled(allTimezones)
  local enabled = {}
  for i = 1, #allTimezones do
    local tz = allTimezones[i]
    if tz.enabled then
      enabled[#enabled + 1] = tz
    end
  end
  return enabled
end

-- Fetch the current time for a given IANA timezone string and publish state
local function fetchAndPublish(tzEntry, dateFormat)
  local tzName   = tzEntry.timezone
  local cityName = tzEntry.name
  local cmd      = "TZ=" .. tzName .. " date '" .. dateFormat .. "'"

  noctalia.runAsync(cmd, function(output, exitCode)
    if exitCode == 0 then
      local timeStr = output:match("^%s*(.-)%s*$") -- trim whitespace
      noctalia.state.set("currentTime",     timeStr)
      noctalia.state.set("currentCity",     cityName)
      noctalia.state.set("currentTimezone", tzName)
    else
      noctalia.log.warn("world-clock: date command failed for " .. tzName)
      noctalia.state.set("currentTime",     "--:--")
      noctalia.state.set("currentCity",     cityName)
      noctalia.state.set("currentTimezone", tzName)
    end
  end)
end

-- Called by the runtime every updateInterval milliseconds
function update()
  local rotationInterval = noctalia.settings.get("rotationInterval") or 5000
  local timeFormat       = noctalia.settings.get("timeFormat")       or "HH:mm"
  local dateFormat       = toDateFormat(timeFormat)

  -- Rebuild timezone list (cheap, settings are cached by the runtime)
  local allTimezones = loadTimezones()
  enabledTimezones   = rebuildEnabled(allTimezones)

  if #enabledTimezones == 0 then
    noctalia.state.set("currentTime",     "--:--")
    noctalia.state.set("currentCity",     "No timezone")
    noctalia.state.set("currentTimezone", "")
    return
  end

  -- Clamp index in case the list shrank
  if currentIndex > #enabledTimezones then
    currentIndex = 1
  end

  -- Advance rotation counter (update() is called every 1000 ms)
  elapsedMs = elapsedMs + 1000
  if elapsedMs >= rotationInterval then
    elapsedMs    = 0
    currentIndex = (currentIndex % #enabledTimezones) + 1
  end

  fetchAndPublish(enabledTimezones[currentIndex], dateFormat)
end

-- Set the polling interval to 1 second
noctalia.setUpdateInterval(1000)
