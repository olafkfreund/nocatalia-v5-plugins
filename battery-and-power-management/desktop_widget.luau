-- Battery & Power Management — desktop widget.

local batPercent = 0
local wattNum = 0.0
local batStatus = "Unknown"
local timeRemaining = "..."
local currentProfile = "balanced"
local batteryThreshold = 80

local function getStatusText(status)
  local key = "battery.status_unknown"
  if status == "Charging" then key = "battery.status_charging"
  elseif status == "Full" then key = "battery.status_full"
  elseif status == "Discharging" then key = "battery.status_discharging"
  elseif status == "Not charging" then key = "battery.status_not_charging"
  end
  return noctalia.tr(key) or status
end

local function setProfile(prof)
  noctalia.state.set("command", { action = "set_profile", value = prof })
end

local function setThreshold(val)
  noctalia.state.set("command", { action = "set_threshold", value = val })
end

-- Actions triggerable by clicks
function selectSaver() setProfile("power-saver") end
function selectBalanced() setProfile("balanced") end
function selectPerformance() setProfile("performance") end

function select60() setThreshold(60) end
function select80() setThreshold(80) end
function select100() setThreshold(100) end

local function render()
  local isCharging = (batStatus == "Charging" or batStatus == "Full")
  local statusText = getStatusText(batStatus)
  
  local timeText = "..."
  if isCharging then
    local fmt = noctalia.tr("battery.time_to_full") or "Time to full: {time}"
    timeText = string.gsub(fmt, "{time}", timeRemaining)
  elseif batStatus == "Discharging" then
    local fmt = noctalia.tr("battery.remaining") or "Remaining: {time}"
    timeText = string.gsub(fmt, "{time}", timeRemaining)
  else
    timeText = string.format("Power Draw: %.1f W", wattNum)
  end

  local rows = {
    -- Battery Status Row
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = `Capacity: {batPercent}%`, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.label({ text = statusText, fontSize = 12, color = "on_surface_variant" })
    }),
    ui.label({ text = timeText, fontSize = 11, color = "on_surface_variant" }),
    
    -- Power Profile Section
    ui.label({ text = "Power Profile", fontSize = 13, fontWeight = "semibold", color = "primary" }),
    ui.row({ gap = 8 }, {
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
    }),

    -- Battery Charge Limit Section
    ui.label({ text = `Charge Limit: {batteryThreshold}%`, fontSize = 13, fontWeight = "semibold", color = "primary" }),
    ui.row({ gap = 8 }, {
      ui.button({
        text = "60% (Max Life)",
        variant = if batteryThreshold == 60 then "primary" else "outline",
        onClick = "select60"
      }),
      ui.button({
        text = "80% (Balanced)",
        variant = if batteryThreshold == 80 then "primary" else "outline",
        onClick = "select80"
      }),
      ui.button({
        text = "100% (Full)",
        variant = if batteryThreshold == 100 then "primary" else "outline",
        onClick = "select100"
      })
    })
  }

  desktopWidget.render(ui.column({ gap = 12, align = "left" }, rows))
end

noctalia.state.watch("batPercent", function(val)
  batPercent = tonumber(val) or 0
  render()
end)

noctalia.state.watch("batStatus", function(val)
  batStatus = if type(val) == "string" then val else "Unknown"
  render()
end)

noctalia.state.watch("wattNum", function(val)
  wattNum = tonumber(val) or 0.0
  render()
end)

noctalia.state.watch("timeRemaining", function(val)
  timeRemaining = if type(val) == "string" then val else "..."
  render()
end)

noctalia.state.watch("currentProfile", function(val)
  currentProfile = if type(val) == "string" then val else "balanced"
  render()
end)

noctalia.state.watch("batteryThreshold", function(val)
  batteryThreshold = tonumber(val) or 80
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
