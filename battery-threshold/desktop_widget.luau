-- Battery Threshold Control — desktop widget.

local currentThreshold = -1
local isAvailable = false
local isWritable = false

local function setThreshold(val)
  noctalia.state.set("command", { action = "set_threshold", value = val })
end

function select60() setThreshold(60) end
function select80() setThreshold(80) end
function select100() setThreshold(100) end

local function render()
  local title = noctalia.tr("panel.title") or "Battery Threshold"
  local rows = {
    ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "primary" })
  }

  if not isAvailable then
    local notAvail = noctalia.tr("panel.not-available") or "Not available on this system"
    table.insert(rows, ui.label({ text = notAvail, fontSize = 12, color = "error" }))
    desktopWidget.render(ui.column({ gap = 8, align = "left" }, rows))
    return
  end

  table.insert(rows, ui.label({ text = `Current Limit: {currentThreshold}%`, fontSize = 14, fontWeight = "semibold" }))

  if not isWritable then
    local readOnly = noctalia.tr("panel.read-only") or "Read-only: Install udev rule for write access"
    table.insert(rows, ui.label({ text = readOnly, fontSize = 11, color = "warning" }))
  else
    table.insert(rows, ui.row({ gap = 8 }, {
      ui.button({
        text = "60% (Max Life)",
        variant = if currentThreshold == 60 then "primary" else "outline",
        onClick = "select60"
      }),
      ui.button({
        text = "80% (Balanced)",
        variant = if currentThreshold == 80 then "primary" else "outline",
        onClick = "select80"
      }),
      ui.button({
        text = "100% (Full)",
        variant = if currentThreshold == 100 then "primary" else "outline",
        onClick = "select100"
      })
    }))
  end

  desktopWidget.render(ui.column({ gap = 10, align = "left" }, rows))
end

noctalia.state.watch("currentThreshold", function(val)
  currentThreshold = tonumber(val) or -1
  render()
end)

noctalia.state.watch("isAvailable", function(val)
  isAvailable = val == true
  render()
end)

noctalia.state.watch("isWritable", function(val)
  isWritable = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
