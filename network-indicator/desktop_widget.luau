-- Network Indicator — desktop widget.

local rxSpeed = 0
local txSpeed = 0

local function formatSpeed(bytes)
  if bytes < 1024 then
    return string.format("%d B/s", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB/s", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format("%.1f MB/s", bytes / (1024 * 1024))
  else
    return string.format("%.1f GB/s", bytes / (1024 * 1024 * 1024))
  end
end

local function render()
  local byteThresholdActive = tonumber(noctalia.getConfig("byteThresholdActive")) or 5000
  local txActive = txSpeed >= byteThresholdActive
  local rxActive = rxSpeed >= byteThresholdActive

  local rows = {
    ui.label({ text = "Network Activity", fontSize = 16, fontWeight = "bold", color = "primary" }),
    
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = "Upload:", fontSize = 13, color = "on_surface_variant" }),
      ui.label({ 
        text = `▲ {formatSpeed(txSpeed)}`, 
        fontSize = 14, 
        fontWeight = "bold", 
        color = if txActive then "primary" else "on_surface" 
      })
    }),
    
    ui.row({ gap = 12, align = "center" }, {
      ui.label({ text = "Download:", fontSize = 13, color = "on_surface_variant" }),
      ui.label({ 
        text = `▼ {formatSpeed(rxSpeed)}`, 
        fontSize = 14, 
        fontWeight = "bold", 
        color = if rxActive then "primary" else "on_surface" 
      })
    })
  }

  desktopWidget.render(ui.column({ gap = 10, padding = 16 }, rows))
end

noctalia.state.watch("rxSpeed", function(val)
  rxSpeed = tonumber(val) or 0
  render()
end)

noctalia.state.watch("txSpeed", function(val)
  txSpeed = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
