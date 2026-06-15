-- Weather Indicator — background service.
-- Periodically fetches weather condition and forecasts.

noctalia.setUpdateInterval(5000) -- Check intervals every 5 seconds

local lastFetchTime = 0
local refreshing = false
local lat = ""
local lon = ""
local cityName = ""

local function fetchWeather(latitude, longitude, resolvedCity)
  refreshing = true
  noctalia.state.set("refreshing", true)
  
  local useFahr = noctalia.getConfig("useFahrenheit") == true
  local tempUnit = if useFahr then "fahrenheit" else "celsius"
  
  local url = `https://api.open-meteo.com/v1/forecast?latitude={latitude}&longitude={longitude}&current=temperature_2m,is_day,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&temperature_unit={tempUnit}&timezone=auto`
  
  noctalia.http({ url = url }, function(res)
    refreshing = false
    noctalia.state.set("refreshing", false)
    
    if not res.ok then
      noctalia.log(`Weather: API call failed. Status: {res.status}`)
      noctalia.state.set("has_data", false)
      return
    end
    
    local data = noctalia.json.decode(res.body)
    if type(data) ~= "table" or not data.current then
      noctalia.log("Weather: Invalid API response")
      noctalia.state.set("has_data", false)
      return
    end
    
    -- Extract and save details
    local current = data.current
    local daily = data.daily
    
    noctalia.state.set("weather_temp", tonumber(current.temperature_2m) or 0)
    noctalia.state.set("weather_code", tonumber(current.weather_code) or 0)
    noctalia.state.set("weather_is_day", current.is_day == 1)
    
    local customCity = noctalia.getConfig("customCityName") or ""
    local displayName = if customCity ~= "" then customCity else resolvedCity
    noctalia.state.set("city_name", displayName)
    
    -- Daily forecasts
    if daily then
      local forecast = {}
      local daysCount = daily.time and #daily.time or 0
      for i = 1, daysCount do
        table.insert(forecast, {
          time = daily.time[i],
          weather_code = daily.weather_code[i],
          temp_max = daily.temperature_2m_max[i],
          temp_min = daily.temperature_2m_min[i],
          sunrise = daily.sunrise[i],
          sunset = daily.sunset[i]
        })
      end
      noctalia.state.set("forecast", forecast)
    end
    
    noctalia.state.set("has_data", true)
  end)
end

local function poll()
  if refreshing then return end
  
  local now = os.clock()
  local customLat = noctalia.getConfig("customLatitude") or ""
  local customLon = noctalia.getConfig("customLongitude") or ""
  local intervalMins = noctalia.getConfig("refreshInterval") or 15
  local refreshInterval = intervalMins * 60

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    
    if customLat ~= "" and customLon ~= "" then
      lat = customLat
      lon = customLon
      cityName = noctalia.getConfig("customCityName") or "Custom Location"
      fetchWeather(lat, lon, cityName)
    else
      -- Resolve IP location
      noctalia.http({ url = "http://ip-api.com/json" }, function(res)
        if res.ok then
          local loc = noctalia.json.decode(res.body)
          if loc and loc.lat and loc.lon then
            lat = tostring(loc.lat)
            lon = tostring(loc.lon)
            cityName = loc.city or "Unknown"
            fetchWeather(lat, lon, cityName)
            return
          end
        end
        noctalia.log("Weather: Failed to geolocate IP")
        noctalia.state.set("has_data", false)
      end)
    end
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    lastFetchTime = 0
    poll()
  end
end)

function update()
  poll()
end
