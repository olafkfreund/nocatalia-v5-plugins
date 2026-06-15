-- Weather Indicator — bar widget.

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

local function formatTemp(temp, useFahr, showUnit)
  local rounded = math.round(temp)
  local unit = if useFahr then "°F" else "°C"
  return `{rounded}{if showUnit then unit else ""}`
end

local function render()
  if not hasData then
    barWidget.setGlyph("weather-cloud-off")
    barWidget.setText("")
    barWidget.setTooltip("No weather data available")
    return
  end

  local showIcon = barWidget.getConfig("showConditionIcon") ~= false
  if showIcon then
    barWidget.setGlyph(weatherSymbolFromCode(weatherCode, weatherIsDay))
  else
    barWidget.setGlyph("")
  end

  local colorKey = barWidget.getConfig("customColor") or "none"
  if colorKey ~= "none" then
    barWidget.setGlyphColor(colorKey)
  else
    barWidget.setGlyphColor("primary")
  end

  local useFahr = barWidget.getConfig("useFahrenheit") == true
  local showVal = barWidget.getConfig("showTempValue") ~= false
  local showUnit = barWidget.getConfig("showTempUnit") ~= false

  if showVal then
    barWidget.setText(formatTemp(weatherTemp, useFahr, showUnit))
  else
    barWidget.setText("")
  end

  -- Tooltip build
  local tooltipOpt = barWidget.getConfig("tooltipOption") or "everything"
  if tooltipOpt == "disable" then
    barWidget.setTooltip(cityName)
    return
  end

  local lines = { cityName }
  local currentStr = formatTemp(weatherTemp, useFahr, true)
  
  if tooltipOpt == "everything" then
    table.insert(lines, `{noctalia.tr("tooltips.current") or "Current"}: {currentStr}`)
  end

  if #forecast > 0 then
    local today = forecast[1]
    if tooltipOpt == "everything" or tooltipOpt == "highlow" then
      local hi = formatTemp(today.temp_max or 0, useFahr, true)
      local lo = formatTemp(today.temp_min or 0, useFahr, true)
      table.insert(lines, `{noctalia.tr("tooltips.high") or "High"}: {hi}`)
      table.insert(lines, `{noctalia.tr("tooltips.low") or "Low"}: {lo}`)
    end

    if tooltipOpt == "everything" or tooltipOpt == "sunrise" then
      local function formatTimeStr(isoStr)
        if not isoStr then return "" end
        -- extract HH:MM
        local hh, mm = isoStr:match("(%d%d):(%d%d)$")
        if not hh then
          hh, mm = isoStr:match("T(%d%d):(%d%d)")
        end
        return if hh then `{hh}:{mm}` else isoStr
      end
      
      local sunriseStr = formatTimeStr(today.sunrise)
      local sunsetStr = formatTimeStr(today.sunset)
      table.insert(lines, `{noctalia.tr("tooltips.sunrise") or "Sunrise"}: {sunriseStr}`)
      table.insert(lines, `{noctalia.tr("tooltips.sunset") or "Sunset"}: {sunsetStr}`)
    end
  end

  barWidget.setTooltip(table.concat(lines, "\n"))
end

function onClick()
  noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
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
  noctalia.setUpdateInterval(10000)
  render()
end
