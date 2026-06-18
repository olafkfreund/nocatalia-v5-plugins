-- service.luau: IdeaPad Battery Health background service
-- Reads and writes conservation_mode via sysfs.
-- Communicates with widget via noctalia.state.

local conservationPath = ""
local conservationMode = 0
local available = false

-- Helper: find the sysfs conservation_mode path
local function findPath(callback)
    noctalia.runAsync(
        "ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode 2>/dev/null | head -1",
        function(output)
            local path = output and output:match("^%s*(.-)%s*$") or ""
            -- Fallback: check the class/power_supply path
            if path == "" then
                path = "/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode"
                noctalia.runAsync(
                    "test -f " .. path .. " && echo yes || echo no",
                    function(result)
                        local exists = result and result:match("^%s*(.-)%s*$") == "yes"
                        if not exists then
                            path = ""
                        end
                        callback(path)
                    end
                )
            else
                callback(path)
            end
        end
    )
end

-- Read current conservation mode value from sysfs
local function readMode()
    if conservationPath == "" then
        return
    end
    noctalia.runAsync(
        "cat " .. conservationPath .. " 2>/dev/null",
        function(output)
            if output then
                local trimmed = output:match("^%s*(.-)%s*$")
                local val = tonumber(trimmed)
                if val ~= nil then
                    conservationMode = val
                    noctalia.state.set("conservationMode", conservationMode)
                end
            end
        end
    )
end

-- Write a conservation mode value (0 or 1) to sysfs
local function writeMode(val, callback)
    if conservationPath == "" then
        if callback then callback(false) end
        return
    end
    noctalia.runAsync(
        "sh -c 'echo " .. tostring(val) .. " > " .. conservationPath .. "'",
        function(output)
            -- Re-read after write to confirm
            readMode()
            if callback then callback(true) end
        end
    )
end

-- Toggle conservation mode between 0 and 1
local function toggleMode()
    local next = 0
    if conservationMode == 0 then
        next = 1
    end
    writeMode(next)
end

-- Initialize: find path, set availability, read initial value
local function init()
    findPath(function(path)
        conservationPath = path
        if path ~= "" then
            available = true
            noctalia.state.set("available", true)
            readMode()
        else
            available = false
            noctalia.state.set("available", false)
            noctalia.state.set("conservationMode", 0)
        end
    end)
end

-- Watch for commands from widget (toggle or set:VALUE)
noctalia.state.watch("command", function(cmd)
    if cmd == "toggle" then
        toggleMode()
    else
        -- Check for "set:VALUE" pattern
        local val = cmd:match("^set:(%d+)$")
        if val ~= nil then
            local numVal = tonumber(val)
            if numVal == 0 or numVal == 1 then
                writeMode(numVal)
            end
        end
    end
    -- Clear command after handling
    noctalia.state.set("command", "")
end)

-- Periodic poll every 30 seconds
noctalia.setUpdateInterval(30000)

function update()
    if available then
        readMode()
    else
        -- Retry discovery in case driver loaded late
        init()
    end
end

-- Run on startup
init()
