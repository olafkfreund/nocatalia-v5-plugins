-- GPU Screen Recorder — shortcut widget.

local state = "idle"
local available = false
local RECORDING_STATES = { "recording", "pending" }
local PENDING_STATES = { "pending", "replay_pending" }

local function send(action)
    noctalia.state.set("command", action)
end

local function render()
    if not available then
        shortcut.setLabel("Screen Recorder (N/A)")
        shortcut.setIcon("video-off")
        shortcut.setActive(false)
        shortcut.setEnabled(false)
        return
    end

    shortcut.setEnabled(true)
    if state == "recording" then
        shortcut.setLabel("Recording...")
        shortcut.setIcon("video")
        shortcut.setActive(true)
    elseif table.find(PENDING_STATES, state) then
        shortcut.setLabel("Pending...")
        shortcut.setIcon("video")
        shortcut.setActive(true)
    elseif state == "replaying" then
        shortcut.setLabel("Replaying...")
        shortcut.setIcon("repeat")
        shortcut.setActive(true)
    else
        shortcut.setLabel("Record Screen")
        shortcut.setIcon("video")
        shortcut.setActive(false)
    end
end

local function applyStatus(status)
    if type(status) == "table" then
        state = status.state or "idle"
        available = if status.available then true else false
    end
    render()
end

function onClick()
    if not available then return end
    if table.find(RECORDING_STATES, state) then
        send("stop")
    elseif state == "idle" then
        send("start")
    end
end

function onRightClick()
    if not available then return end
    if state == "replaying" then
        send("replay-save")
    elseif state == "idle" and noctalia.getConfig("replay_enabled") then
        send("replay-start")
    elseif state == "replay_pending" then
        send("replay-stop")
    end
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
