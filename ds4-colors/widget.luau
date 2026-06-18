-- DS4 Colors — bar widget.
-- Watches service state and renders the gamepad icon with battery info.
-- Left-click re-applies the saved config color to all connected controllers.

local hasController = false
local controllerCount = 0
local batteryLevel = -1

-- Read hideOnEmpty setting from config
local function getHideOnEmpty()
    local v = noctalia.getConfig("hideOnEmpty")
    if v == nil then return false end
    return v == true
end

-- Refresh the bar widget display from current state
local function refreshDisplay()
    if not hasController and getHideOnEmpty() then
        barWidget.setVisible(false)
        return
    end

    barWidget.setVisible(true)
    barWidget.setGlyph("gamepad")

    if batteryLevel >= 0 then
        barWidget.setText(tostring(batteryLevel) .. "%")
    else
        barWidget.setText("")
    end

    -- Build tooltip
    local tooltip
    if controllerCount > 0 then
        tooltip = "DS4: " .. tostring(controllerCount) .. " controller"
        if controllerCount > 1 then
            tooltip = tooltip .. "s"
        end
        if batteryLevel >= 0 then
            tooltip = tooltip .. "\nBattery: " .. tostring(batteryLevel) .. "%"
        end
    else
        tooltip = "DS4: No controllers"
    end
    barWidget.setTooltip(tooltip)
end

-- Watch service state
noctalia.state.watch("hasController", function(val)
    hasController = val == true
    refreshDisplay()
end)

noctalia.state.watch("controllerCount", function(val)
    local n = tonumber(val)
    if n ~= nil then
        controllerCount = n
    else
        controllerCount = 0
    end
    refreshDisplay()
end)

noctalia.state.watch("batteryLevel", function(val)
    local n = tonumber(val)
    if n ~= nil then
        batteryLevel = n
    else
        batteryLevel = -1
    end
    refreshDisplay()
end)

-- Re-apply the saved hex color from config to all controllers
function onClick()
    local hex = noctalia.getConfig("color") or "#0064ff"
    hex = string.gsub(hex, "#", "")
    local r = tonumber(string.sub(hex, 1, 2), 16) or 0
    local g = tonumber(string.sub(hex, 3, 4), 16) or 0
    local b = tonumber(string.sub(hex, 5, 6), 16) or 0
    noctalia.state.set("command", "setColor:" .. tostring(r) .. ":" .. tostring(g) .. ":" .. tostring(b))
end

-- Right-click: no-op (handled by shell context menu)
function onRightClick()
end

-- Called by shell on each update cycle
function update()
    refreshDisplay()
end
