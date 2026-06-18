-- ThinkPad Fan & Thermal - Background Service
-- Polls /proc/acpi/ibm/fan and /sys/class/thermal/thermal_zone0/temp every 3 seconds.
-- Exposes state: fanRpm (int), fanLevel (string), currentTemp (int).
-- Handles IPC event "setLevel" to write a new fan level.

local fanRpm = 0
local fanLevel = "auto"
local currentTemp = 0

-- Poll interval: 3000 ms
noctalia.setUpdateInterval(3000)

-- Parse /proc/acpi/ibm/fan output and update shared state
local function parseFanOutput(output)
    if not output or output == "" then
        return
    end

    local parsedRpm = 0
    local parsedLevel = "auto"

    for line in string.gmatch(output, "[^\n]+") do
        local trimmed = string.match(line, "^%s*(.-)%s*$")
        if string.sub(trimmed, 1, 6) == "speed:" then
            local valStr = string.match(trimmed, "speed:%s*(%d+)")
            if valStr then
                parsedRpm = tonumber(valStr) or 0
            end
        elseif string.sub(trimmed, 1, 6) == "level:" then
            local valStr = string.match(trimmed, "level:%s*(.+)$")
            if valStr then
                parsedLevel = string.lower(string.match(valStr, "^%s*(.-)%s*$"))
            end
        end
    end

    fanRpm = parsedRpm
    fanLevel = parsedLevel
    noctalia.state.set("fanRpm", fanRpm)
    noctalia.state.set("fanLevel", fanLevel)
end

-- Parse temperature sysfs output and update shared state
local function parseTempOutput(output)
    if not output or output == "" then
        return
    end
    local trimmed = string.match(output, "^%s*(.-)%s*$")
    local raw = tonumber(trimmed)
    if raw then
        currentTemp = math.floor(raw / 1000)
        noctalia.state.set("currentTemp", currentTemp)
    end
end

-- Periodic update: read fan and temperature files
function update()
    noctalia.runAsync("cat /proc/acpi/ibm/fan", function(out)
        parseFanOutput(out)
    end)

    noctalia.runAsync("cat /sys/class/thermal/thermal_zone0/temp", function(out)
        parseTempOutput(out)
    end)
end

-- IPC handler: supports "setLevel" to write a fan level override
function onIpc(event, arg)
    if event == "setLevel" then
        if not arg or arg == "" then
            return
        end
        local cleanLevel = string.lower(string.match(arg, "^%s*(.-)%s*$"))
        if cleanLevel == "" or cleanLevel == "unknown" then
            return
        end
        local cmd = "echo level " .. cleanLevel .. " > /proc/acpi/ibm/fan"
        noctalia.runAsync(cmd, function()
            -- Re-read fan state after applying change
            noctalia.runAsync("cat /proc/acpi/ibm/fan", function(out)
                parseFanOutput(out)
            end)
        end)
    end
end
