-- ASUS UM5606 Fan State — bar widget.
-- Displays the fan profile icon and toggles it on click.

local fanState = -1

local function getIcon(state)
  if state == 0 then return "car-fan"
  elseif state == 1 then return "car-fan-1"
  elseif state == 2 then return "car-fan-2"
  elseif state == 3 then return "car-fan-3"
  else return "car-fan"
  end
end

local function getColor(state)
  if state == 3 then return "primary"
  elseif state == 2 then return "tertiary"
  elseif state == 1 then return "secondary"
  else return "on_surface"
  end
end

local function getTooltip(state)
  local key = "tooltip.unknown"
  if state == 0 then key = "tooltip.standard"
  elseif state == 1 then key = "tooltip.quiet"
  elseif state == 2 then key = "tooltip.high"
  elseif state == 3 then key = "tooltip.full"
  end

  local statusText = noctalia.tr(key) or "Unknown"
  return `ASUS Fan Profile\nProfile: {statusText}\n\nClick to cycle profile`
end

local function render()
  barWidget.setGlyph(getIcon(fanState))
  barWidget.setGlyphColor(getColor(fanState))
  barWidget.setTooltip(getTooltip(fanState))
  barWidget.setText("")
end

function onClick()
  local nextState = (fanState + 1) % 4
  noctalia.state.set("command", { action = "set", value = nextState })
end

noctalia.state.watch("fanState", function(val)
  fanState = tonumber(val) or -1
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
