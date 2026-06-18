-- ThinkPad Fan & Thermal - Bar Widget
-- Watches service state and updates the bar widget display.
-- Colorizes the icon based on temperature when colorizeByStatus is enabled.

local fanRpm = 0
local fanLevel = "auto"
local currentTemp = 0

-- Read plugin setting with fallback
local function getColorize()
    local cfg = noctalia.config.get("colorizeByStatus")
    if cfg == nil then
        return true
    end
    return cfg
end

-- Derive glyph color from current temperature
local function glyphColor()
    if not getColorize() then
        return "on_surface"
    end
    if currentTemp > 80 then
        return "error"
    elseif currentTemp >= 60 then
        return "warning"
    else
        return "on_surface"
    end
end

-- Refresh the bar widget display from current state
local function refreshDisplay()
    barWidget.setGlyph("wind")
    barWidget.setText(fanRpm .. " RPM")
    barWidget.setTooltip("Fan: " .. fanLevel .. " | Temp: " .. currentTemp .. "\xC2\xB0C")
    barWidget.setGlyphColor(glyphColor())
end

-- Watch service state keys
noctalia.state.watch("fanRpm", function(val)
    fanRpm = val or 0
    refreshDisplay()
end)

noctalia.state.watch("fanLevel", function(val)
    fanLevel = val or "auto"
    refreshDisplay()
end)

noctalia.state.watch("currentTemp", function(val)
    currentTemp = val or 0
    refreshDisplay()
end)

-- Called once on widget initialisation
function update()
    refreshDisplay()
end
