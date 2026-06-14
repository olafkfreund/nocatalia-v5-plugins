-- Air Quality — bar widget.

local aqi = 0
local hasData = false
local loading = false
local scale = "us"
local stationName = ""
local lastUpdate = ""

local function getAqiColor(val)
  if scale == "eu" then
    if val <= 20 then return "success"
    elseif val <= 40 then return "success"
    elseif val <= 60 then return "warning"
    elseif val <= 80 then return "error"
    elseif val <= 100 then return "error"
    else return "error"
    end
  else
    if val <= 50 then return "success"
    elseif val <= 100 then return "warning"
    elseif val <= 150 then return "warning"
    elseif val <= 200 then return "error"
    elseif val <= 300 then return "error"
    else return "error"
    end
  end
end

local function getAqiLevel(val)
  if scale == "eu" then
    if val <= 20 then return "levels.good"
    elseif val <= 40 then return "levels.fair"
    elseif val <= 60 then return "levels.moderate"
    elseif val <= 80 then return "levels.poor"
    elseif val <= 100 then return "levels.veryPoor"
    else return "levels.extremelyPoor"
    end
  else
    if val <= 50 then return "levels.good"
    elseif val <= 100 then return "levels.moderate"
    elseif val <= 150 then return "levels.unhealthySensitive"
    elseif val <= 200 then return "levels.unhealthy"
    elseif val <= 300 then return "levels.veryUnhealthy"
    else return "levels.hazardous"
    end
  end
end

local function render()
  barWidget.setGlyph("wind")
  
  if loading then
    barWidget.setGlyphColor("primary")
    barWidget.setText("...")
    barWidget.setTooltip("Air Quality: Loading...")
    return
  end

  if not hasData then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("--")
    barWidget.setTooltip("Air Quality: No data")
    return
  end

  barWidget.setGlyphColor(getAqiColor(aqi))
  barWidget.setText(tostring(aqi))
  
  local levelStr = noctalia.tr(getAqiLevel(aqi))
  local tooltip = `Air Quality ({scale:upper()}): {aqi} — {levelStr}\n`
  if stationName ~= "" then
    tooltip ..= `Station: {stationName}\n`
  end
  if lastUpdate ~= "" then
    tooltip ..= `Last Update: {lastUpdate}\n`
  end
  tooltip ..= "\nLeft-click: Show detail notification\nRight-click: Refresh"
  barWidget.setTooltip(tooltip)
end

function onClick()
  if not hasData then return end
  local levelStr = noctalia.tr(getAqiLevel(aqi))
  local text = `AQI: {aqi} ({levelStr})\nStation: {stationName or "Unknown"}\nLast Update: {lastUpdate}`
  noctalia.notify("Air Quality", text)
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("aqi", function(val)
  aqi = tonumber(val) or 0
  render()
end)

noctalia.state.watch("has_data", function(val)
  hasData = val == true
  render()
end)

noctalia.state.watch("loading", function(val)
  loading = val == true
  render()
end)

noctalia.state.watch("station_name", function(val)
  stationName = if type(val) == "string" then val else ""
  render()
end)

noctalia.state.watch("last_update", function(val)
  lastUpdate = if type(val) == "string" then val else ""
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  scale = barWidget.getConfig("aqiScale") or "us"
  render()
end
