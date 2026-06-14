-- Battery Monitor Plus — desktop widget.

local ok = false
local capacity = -1
local status = "Unknown"
local powerWatts = -1.0
local timeToEmpty = 0
local timeToFull = 0
local health = 100
local currentProfile = "balanced"
local showPowerProfiles = false

local function formatDurationCompact(seconds)
  if seconds <= 0 then return "" end
  local totalMinutes = math.max(1, math.round(seconds / 60))
  local hours = math.floor(totalMinutes / 60)
  local minutes = totalMinutes % 60
  if hours > 0 then
    return if minutes > 0 then `{hours}h{minutes}m` else `{hours}h`
  end
  return `{minutes}m`
end

local function selectProfile(prof)
  noctalia.state.set("command", { action = "set_profile", value = prof })
end

function selectSaver() selectProfile("power-saver") end
function selectBalanced() selectProfile("balanced") end
function selectPerformance() selectProfile("performance") end

function refreshData()
  noctalia.state.set("command", { action = "refresh" })
end

local function render()
  if not ok then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "No battery detected", fontSize = 16, color = "on_surface_variant" })
    }))
    return
  end

  local isCharging = (status == "Charging" or status == "Full")
  local timeText = "..."
  local sec = if isCharging then timeToFull else timeToEmpty
  local formattedTime = formatDurationCompact(sec)
  
  if isCharging then
    timeText = if formattedTime ~= "" then `Time to full: {formattedTime}` else "Fully charged"
  else
    timeText = if formattedTime ~= "" then `Remaining: {formattedTime}` else "Discharging"
  end

  local rows = {
    ui.label({ text = "Battery Monitor Plus", fontSize = 18, fontWeight = "bold", color = "primary" }),
    
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = `Capacity: {capacity}%`, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.label({ text = status, fontSize = 12, color = "on_surface_variant" })
    }),

    ui.label({ text = timeText, fontSize = 12, color = "on_surface" }),
    ui.label({ text = string.format("Power Draw: %.1f W", powerWatts), fontSize = 11, color = "on_surface_variant" }),
    ui.label({ text = `Health: {health}%`, fontSize = 11, color = "on_surface_variant" })
  }

  if showPowerProfiles then
    table.insert(rows, ui.label({ text = "Power Profile", fontSize = 13, fontWeight = "semibold", color = "primary" }))
    table.insert(rows, ui.row({ gap = 8 }, {
      ui.button({
        text = "Power Saver",
        variant = if currentProfile == "power-saver" then "primary" else "outline",
        onClick = "selectSaver"
      }),
      ui.button({
        text = "Balanced",
        variant = if currentProfile == "balanced" then "primary" else "outline",
        onClick = "selectBalanced"
      }),
      ui.button({
        text = "Performance",
        variant = if currentProfile == "performance" then "primary" else "outline",
        onClick = "selectPerformance"
      })
    }))
  end

  table.insert(rows, ui.button({ text = "Refresh", variant = "outline", onClick = "refreshData" }))

  desktopWidget.render(ui.column({ gap = 10, align = "left" }, rows))
end

noctalia.state.watch("ok", function(val)
  ok = val == true
  render()
end)

noctalia.state.watch("capacity", function(val)
  capacity = tonumber(val) or -1
  render()
end)

noctalia.state.watch("status", function(val)
  status = if type(val) == "string" then val else "Unknown"
  render()
end)

noctalia.state.watch("powerWatts", function(val)
  powerWatts = tonumber(val) or -1.0
  render()
end)

noctalia.state.watch("timeToEmpty", function(val)
  timeToEmpty = tonumber(val) or 0
  render()
end)

noctalia.state.watch("timeToFull", function(val)
  timeToFull = tonumber(val) or 0
  render()
end)

noctalia.state.watch("health", function(val)
  health = tonumber(val) or 100
  render()
end)

noctalia.state.watch("currentProfile", function(val)
  currentProfile = if type(val) == "string" then val else "balanced"
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  showPowerProfiles = desktopWidget.getConfig("showPowerProfiles") == true
  render()
end
