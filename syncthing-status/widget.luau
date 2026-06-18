-- syncthing-status: widget.luau
-- Bar widget that displays Syncthing sync state with appropriate icon and color.

-- Local state mirrors
local syncState  = "unconfigured"
local detail     = ""
local syncingCount = 0
local errorCount   = 0

-- Map sync state to a glyph name
local function glyphForState(state)
    if state == "syncing" then
        return "refresh"
    elseif state == "idle" or state == "ok" then
        return "check"
    elseif state == "error" or state == "offline" or state == "unauthorized" then
        return "alert-circle"
    elseif state == "paused" or state == "disconnected" or state == "disabled" then
        return "pause-circle"
    else
        -- unconfigured or unknown
        return "help-circle"
    end
end

-- Map sync state to a color token
local function colorForState(state)
    if state == "syncing" then
        return "primary"
    elseif state == "idle" or state == "ok" then
        return "success"
    elseif state == "error" or state == "offline" or state == "unauthorized" then
        return "error"
    else
        -- paused / disconnected / disabled / unconfigured
        return "on_surface"
    end
end

-- Build the text label shown next to the icon
local function labelText(state, syncing, errors)
    if state == "syncing" and syncing > 0 then
        return tostring(syncing)
    elseif state == "error" and errors > 0 then
        return tostring(errors)
    else
        return ""
    end
end

-- Build tooltip string
local function buildTooltip(state, det)
    local stateName = state or "unconfigured"
    if det and det ~= "" then
        return "Syncthing — " .. stateName .. "\n" .. det
    else
        return "Syncthing — " .. stateName
    end
end

-- Apply current state to the bar widget
local function render()
    local glyph = glyphForState(syncState)
    local color = colorForState(syncState)
    local text  = labelText(syncState, syncingCount, errorCount)
    local tip   = buildTooltip(syncState, detail)

    barWidget.setGlyph(glyph)
    barWidget.setGlyphColor(color)
    barWidget.setText(text)
    barWidget.setTooltip(tip)
    barWidget.setVisible(true)
end

-- Watch state keys published by service.luau
noctalia.state.watch("syncState", function(val)
    syncState = val or "unconfigured"
    render()
end)

noctalia.state.watch("detail", function(val)
    detail = val or ""
    render()
end)

noctalia.state.watch("syncingCount", function(val)
    syncingCount = tonumber(val) or 0
    render()
end)

noctalia.state.watch("errorCount", function(val)
    errorCount = tonumber(val) or 0
    render()
end)

-- Handle click: send a refresh command to the service
function onClick()
    noctalia.state.set("command", "refresh")
end

-- Handle right-click: no-op (context menu handled by shell)
function onRightClick()
end

-- Initial render with default (possibly already-populated) state
function update()
    render()
end

-- Perform an initial render immediately
render()
