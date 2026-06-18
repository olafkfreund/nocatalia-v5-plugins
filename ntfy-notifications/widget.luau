-- ntfy-notifications: widget.luau
-- Bar widget: shows a bell icon and unread notification count.
-- Watches messageCount and lastMessage state from service.luau.

local count       = 0
local lastMessage = ""

-- Watch notification count published by the service
noctalia.state.watch("messageCount", function(value)
    count = tonumber(value) or 0
    refreshWidget()
end)

-- Watch last message summary for richer tooltip
noctalia.state.watch("lastMessage", function(value)
    lastMessage = value or ""
    refreshWidget()
end)

-- Render the widget based on current state
function refreshWidget()
    -- Glyph: bell (filled when there are unread messages)
    barWidget.setGlyph("bell")

    if count > 0 then
        local displayCount
        if count > 99 then
            displayCount = "99+"
        else
            displayCount = tostring(count)
        end
        barWidget.setText(displayCount)

        local tooltipText
        if count == 1 then
            tooltipText = "1 unread notification"
        else
            tooltipText = tostring(count) .. " unread notifications"
        end
        if lastMessage ~= "" then
            tooltipText = tooltipText .. " — " .. lastMessage
        end
        barWidget.setTooltip(tooltipText)
    else
        barWidget.setText("")
        barWidget.setTooltip("ntfy Notifications")
    end

    barWidget.setVisible(true)
end

-- onClick: send a refresh command to the service
function onClick()
    noctalia.state.set("command", "refresh")
end

-- onRightClick: reset read count
function onRightClick()
    noctalia.state.set("command", "reset")
end

-- update() is called once on widget load
function update()
    -- Initialise with current (possibly cached) state
    local cachedCount = tonumber(noctalia.state.get("messageCount")) or 0
    local cachedMsg   = noctalia.state.get("lastMessage") or ""
    count       = cachedCount
    lastMessage = cachedMsg
    refreshWidget()
end
