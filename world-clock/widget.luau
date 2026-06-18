-- World Clock Bar Widget
-- Watches state published by service.luau and updates the bar widget display.

local currentTime     = "--:--"
local currentCity     = ""
local currentTimezone = ""

-- Watch for time updates from the service
noctalia.state.watch("currentTime", function(value)
  currentTime = value or "--:--"
  refreshWidget()
end)

noctalia.state.watch("currentCity", function(value)
  currentCity = value or ""
  refreshWidget()
end)

noctalia.state.watch("currentTimezone", function(value)
  currentTimezone = value or ""
  refreshWidget()
end)

-- Re-render the bar widget whenever any state changes
function refreshWidget()
  local label = ""
  if currentCity ~= "" then
    label = currentCity .. "  " .. currentTime
  else
    label = currentTime
  end

  barWidget.setText(label)

  local tooltip = ""
  if currentCity ~= "" then
    tooltip = currentCity .. "\n" .. currentTime
    if currentTimezone ~= "" then
      tooltip = tooltip .. "\n" .. currentTimezone
    end
  else
    tooltip = currentTime
  end

  barWidget.setTooltip(tooltip)
end

-- Called once on startup by the runtime
function update()
  barWidget.setGlyph("clock")
  barWidget.setGlyphColor("on_surface")

  -- Render initial placeholder until the service publishes state
  barWidget.setText("--:--")
  barWidget.setTooltip("World Clock")
  barWidget.setVisible(true)
end
