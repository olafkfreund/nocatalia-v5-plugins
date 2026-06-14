-- Air Quality — desktop widget.

local aqi = 0
local hasData = false
local loading = false
local scale = "us"
local stationName = ""
local pm25 = 0
local pm10 = 0

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
  if loading then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "Loading...", fontSize = 16, color = "on_surface_variant" })
    }))
    return
  end

  if not hasData then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "No Data", fontSize = 16, color = "on_surface_variant" }),
      ui.button({ text = "Refresh", variant = "primary", onClick = "refreshData" })
    }))
    return
  end

  local levelStr = noctalia.tr(getAqiLevel(aqi))
  local color = getAqiColor(aqi)

  local rows = {
    ui.label({
      text = tostring(aqi),
      fontSize = 42,
      fontWeight = "bold",
      color = color,
    }),
    ui.label({
      text = levelStr,
      fontSize = 16,
      fontWeight = "semibold",
      color = color,
    }),
    ui.label({
      text = stationName ~= "" and stationName or "Air Quality",
      fontSize = 12,
      color = "on_surface_variant",
    }),
    ui.row({ gap = 12 }, {
      ui.label({ text = `PM2.5: {pm25}`, fontSize = 11, color = "on_surface_variant" }),
      ui.label({ text = `PM10: {pm10}`, fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.button({
      text = "Refresh",
      variant = "outline",
      onClick = "refreshData",
    })
  }

  desktopWidget.render(ui.column({ gap = 6, align = "center" }, rows))
end

function refreshData()
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

noctalia.state.watch("pm25", function(val)
  pm25 = tonumber(val) or 0
  render()
end)

noctalia.state.watch("pm10", function(val)
  pm10 = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  scale = desktopWidget.getConfig("aqiScale") or "us"
  render()
end
