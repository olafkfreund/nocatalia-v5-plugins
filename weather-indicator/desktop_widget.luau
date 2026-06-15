-- Weather Indicator — desktop widget.

local weatherTemp = 0
local weatherCode = 0
local weatherIsDay = true
local cityName = ""
local hasData = false
local forecast = {}

local function weatherSymbolFromCode(code, isDay)
  isDay = (isDay ~= false)
  if code == 0 then
    return if isDay then "weather-sunny" else "weather-night"
  elseif code == 1 or code == 2 or code == 3 then
    return if isDay then "weather-partly-cloudy" else "weather-night-partly-cloudy"
  elseif code == 45 or code == 48 then
    return "weather-fog"
  elseif code == 51 or code == 53 or code == 55 or code == 56 or code == 57 then
    return "weather-drizzle"
  elseif code == 61 or code == 63 or code == 65 or code == 66 or code == 67 then
    return "weather-rainy"
  elseif code == 71 or code == 73 or code == 75 or code == 77 then
    return "weather-snowy"
  elseif code == 80 or code == 81 or code == 82 then
    return "weather-pouring"
  elseif code == 85 or code == 86 then
    return "weather-snowy-heavy"
  elseif code == 95 or code == 96 or code == 99 then
    return "weather-lightning"
  else
    return "weather-cloudy"
  end
end

local function formatTemp(temp, useFahr)
  local rounded = math.round(temp)
  local unit = if useFahr then "°F" else "°C"
  return `{rounded}{unit}`
end

local function getDayOfWeekName(dateStr)
  if not dateStr then return "" end
  local y, m, d = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
  if y then
    local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return os.date("%a", t):upper()
  end
  return dateStr
end

function triggerRefresh()
  noctalia.state.set("command", "refresh")
end

local function render()
  if not hasData then
    desktopWidget.render(ui.column({ gap = 10, align = "center", padding = 16 }, {
      ui.label({ text = "No weather data", fontSize = 16, color = "on_surface_variant" }),
      ui.button({ text = "Refresh", variant = "primary", onClick = "triggerRefresh" })
    }))
    return
  end

  local useFahr = noctalia.getConfig("useFahrenheit") == true
  local currentIcon = weatherSymbolFromCode(weatherCode, weatherIsDay)

  -- Build forecast items
  local forecastCols = {}
  local limit = math.min(5, #forecast)
  for i = 1, limit do
    local day = forecast[i]
    table.insert(forecastCols, ui.column({ gap = 4, align = "center" }, {
      ui.label({ text = getDayOfWeekName(day.time), fontSize = 11, fontWeight = "semibold", color = "on_surface_variant" }),
      ui.button({
        text = weatherSymbolFromCode(day.weather_code, true), -- use condition glyph
        variant = "flat"
      }),
      ui.label({
        text = `{math.round(day.temp_max)}°`,
        fontSize = 12,
        fontWeight = "bold",
        color = "on_surface"
      }),
      ui.label({
        text = `{math.round(day.temp_min)}°`,
        fontSize = 11,
        color = "on_surface_variant"
      })
    }))
  end

  local rows = {
    ui.label({
      text = cityName ~= "" and cityName or "Weather",
      fontSize = 16,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.row({ gap = 12, align = "center" }, {
      ui.button({
        text = currentIcon,
        variant = "flat"
      }),
      ui.label({
        text = formatTemp(weatherTemp, useFahr),
        fontSize = 32,
        fontWeight = "bold",
        color = "primary"
      })
    }),
    ui.row({ gap = 14, align = "center" }, forecastCols),
    ui.button({
      text = "Refresh",
      variant = "outline",
      onClick = "triggerRefresh"
    })
  }

  desktopWidget.render(ui.column({ gap = 12, align = "center", padding = 16 }, rows))
end

noctalia.state.watch("weather_temp", function(val)
  weatherTemp = tonumber(val) or 0
  render()
end)

noctalia.state.watch("weather_code", function(val)
  weatherCode = tonumber(val) or 0
  render()
end)

noctalia.state.watch("weather_is_day", function(val)
  weatherIsDay = val == true
  render()
end)

noctalia.state.watch("city_name", function(val)
  cityName = tostring(val)
  render()
end)

noctalia.state.watch("forecast", function(val)
  forecast = if type(val) == "table" then val else {}
  render()
end)

noctalia.state.watch("has_data", function(val)
  hasData = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
