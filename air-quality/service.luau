-- Air Quality — background service.
-- Periodically fetches air quality index and pollutant values.

noctalia.setUpdateInterval(5000) -- Check intervals every 5 seconds

local lastFetchTime = 0
local scale = "us"
local dataSource = "open-meteo"
local aqicnToken = ""
local useNoctaliaLocation = true
local customLatitude = ""
local customLongitude = ""
local refreshInterval = 1800 -- seconds (30 mins default)

local function fetchAirQuality(lat, lon)
  noctalia.state.set("loading", true)
  
  if dataSource == "aqicn" then
    if aqicnToken == "" then
      noctalia.log("Air Quality: AQICN token is missing")
      noctalia.state.set("loading", false)
      noctalia.state.set("has_data", false)
      return
    end
    
    local url = `https://api.waqi.info/feed/geo:{lat};{lon}/?token={aqicnToken}`
    noctalia.http({ url = url }, function(res)
      noctalia.state.set("loading", false)
      if not res.ok then
        noctalia.log(`Air Quality: AQICN API failed. Status: {res.status}`)
        return
      end
      
      local response = noctalia.json.decode(res.body)
      if type(response) ~= "table" or response.status ~= "ok" then
        noctalia.log("Air Quality: AQICN API error response")
        return
      end
      
      local data = response.data
      noctalia.state.set("aqi", tonumber(data.aqi) or 0)
      noctalia.state.set("station_name", data.city and data.city.name or "")
      noctalia.state.set("pm25", data.iaqi and data.iaqi.pm25 and data.iaqi.pm25.v or 0)
      noctalia.state.set("pm10", data.iaqi and data.iaqi.pm10 and data.iaqi.pm10.v or 0)
      noctalia.state.set("ozone", data.iaqi and data.iaqi.o3 and data.iaqi.o3.v or 0)
      noctalia.state.set("no2", data.iaqi and data.iaqi.no2 and data.iaqi.no2.v or 0)
      noctalia.state.set("co", data.iaqi and data.iaqi.co and data.iaqi.co.v or 0)
      noctalia.state.set("so2", data.iaqi and data.iaqi.so2 and data.iaqi.so2.v or 0)
      noctalia.state.set("last_update", os.date("%H:%M"))
      noctalia.state.set("has_data", true)
    end)
  else
    -- Open-Meteo
    local url = `https://air-quality-api.open-meteo.com/v1/air-quality?latitude={lat}&longitude={lon}&current=us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,carbon_monoxide,sulphur_dioxide&timezone=auto`
    noctalia.http({ url = url }, function(res)
      noctalia.state.set("loading", false)
      if not res.ok then
        noctalia.log(`Air Quality: Open-Meteo failed. Status: {res.status}`)
        return
      end
      
      local data = noctalia.json.decode(res.body)
      if type(data) ~= "table" or not data.current then
        noctalia.log("Air Quality: Invalid response from Open-Meteo")
        return
      end
      
      local current = data.current
      local aqiVal = if scale == "eu" then current.european_aqi else current.us_aqi
      noctalia.state.set("aqi", tonumber(aqiVal) or 0)
      noctalia.state.set("station_name", "Open-Meteo")
      noctalia.state.set("pm25", current.pm2_5 or 0)
      noctalia.state.set("pm10", current.pm10 or 0)
      noctalia.state.set("ozone", current.ozone or 0)
      noctalia.state.set("no2", current.nitrogen_dioxide or 0)
      noctalia.state.set("co", current.carbon_monoxide or 0)
      noctalia.state.set("so2", current.sulphur_dioxide or 0)
      noctalia.state.set("last_update", os.date("%H:%M"))
      noctalia.state.set("has_data", true)
    end)
  end
end

local function poll()
  local now = os.clock()
  scale = noctalia.getConfig("aqiScale") or "us"
  dataSource = noctalia.getConfig("dataSource") or "open-meteo"
  aqicnToken = noctalia.getConfig("aqicnToken") or ""
  useNoctaliaLocation = noctalia.getConfig("useNoctaliaLocation") ~= false
  customLatitude = noctalia.getConfig("customLatitude") or ""
  customLongitude = noctalia.getConfig("customLongitude") or ""
  
  local intervalMins = noctalia.getConfig("refreshInterval") or 30
  refreshInterval = intervalMins * 60

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    
    if useNoctaliaLocation then
      -- Fallback to IP geolocation
      noctalia.http({ url = "http://ip-api.com/json" }, function(res)
        if res.ok then
          local locationData = noctalia.json.decode(res.body)
          if locationData and locationData.lat and locationData.lon then
            fetchAirQuality(locationData.lat, locationData.lon)
            return
          end
        end
        -- If IP geolocation fails, fall back to custom coordinates if set
        if customLatitude ~= "" and customLongitude ~= "" then
          fetchAirQuality(customLatitude, customLongitude)
        else
          noctalia.log("Air Quality: Geolocation failed and no custom coordinates configured")
          noctalia.state.set("has_data", false)
        end
      end)
    else
      if customLatitude ~= "" and customLongitude ~= "" then
        fetchAirQuality(customLatitude, customLongitude)
      else
        noctalia.log("Air Quality: Custom coordinates configured but empty")
        noctalia.state.set("has_data", false)
      end
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
