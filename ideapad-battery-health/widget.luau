-- widget.luau: IdeaPad Battery Health bar widget
-- Displays conservation mode status and allows toggle on click.

local conservationMode = 0
local available = false

-- Update the bar widget display based on current state
local function refreshDisplay()
    if not available then
        barWidget.setVisible(false)
        return
    end

    barWidget.setVisible(true)
    barWidget.setGlyph("battery")

    if conservationMode == 1 then
        barWidget.setGlyphColor("success")
        barWidget.setTooltip("Conservation ON - click to disable")
    else
        barWidget.setGlyphColor("on_surface_variant")
        barWidget.setTooltip("Conservation OFF - click to enable")
    end
end

-- Watch conservation mode state from service
noctalia.state.watch("conservationMode", function(val)
    local num = tonumber(val)
    if num ~= nil then
        conservationMode = num
    else
        conservationMode = 0
    end
    refreshDisplay()
end)

-- Watch availability state from service
noctalia.state.watch("available", function(val)
    available = val == true or val == "true"
    refreshDisplay()
end)

-- Called when user left-clicks the widget
function onClick()
    noctalia.state.set("command", "toggle")
end

-- Called on right-click (no-op, handled by shell context menu)
function onRightClick()
end

-- Called by the shell on each update cycle
function update()
    refreshDisplay()
end
