-- DS4 Colors — background service.
-- Scans for DualShock 4 / DualSense controllers via sysfs LED entries.
-- Reads battery level and applies LED colors via shell scripts.
-- Exposes state: hasController (bool), controllerCount (int), batteryLevel (int).
-- Handles "setColor:R:G:B" commands sent through noctalia.state "command".

local pluginDir = noctalia.pluginDir or ""

-- Internal controller table: basePath -> { separator }
local controllers = {}
local controllerCount = 0
local batteryLevel = -1

-- Poll every 5 seconds
noctalia.setUpdateInterval(5000)

-- Helper: clamp integer to 0-255
local function clamp(n)
    if n < 0 then return 0 end
    if n > 255 then return 255 end
    return n
end

-- Helper: parse "#rrggbb" hex string to r, g, b integers
local function hexToRgb(hex)
    hex = string.gsub(hex, "#", "")
    local r = tonumber(string.sub(hex, 1, 2), 16) or 0
    local g = tonumber(string.sub(hex, 3, 4), 16) or 0
    local b = tonumber(string.sub(hex, 5, 6), 16) or 0
    return r, g, b
end

-- Apply R/G/B to every detected controller
local function applyColorToAll(r, g, b)
    r = clamp(r)
    g = clamp(g)
    b = clamp(b)
    for basePath, ctrl in pairs(controllers) do
        local cmd = "sh "
            .. pluginDir .. "/scripts/set_ds4_color.sh "
            .. basePath .. " "
            .. ctrl.separator .. " "
            .. tostring(r) .. " "
            .. tostring(g) .. " "
            .. tostring(b)
        noctalia.runAsync(cmd, function(res)
            -- Fire and forget; errors are silently ignored (udev rules required)
        end)
    end
end

-- Apply the saved hex color from plugin config to all controllers
local function applyConfigColor()
    local hex = noctalia.getConfig("color") or "#0064ff"
    local r, g, b = hexToRgb(hex)
    applyColorToAll(r, g, b)
end

-- Scan battery level and push state
local function scanBattery()
    local cmd = "sh " .. pluginDir .. "/scripts/scan_battery.sh"
    noctalia.runAsync(cmd, function(res)
        local raw = (res.stdout or ""):match("^%s*(.-)%s*$")
        local level = tonumber(raw) or -1
        batteryLevel = level
        noctalia.state.set("batteryLevel", batteryLevel)
    end)
end

-- Parse scan_controllers.sh output and rebuild controller table
local function parseScanOutput(output)
    local newControllers = {}
    local newCount = 0

    for line in (output .. "\n"):gmatch("([^\n]*)\n") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            -- Line format: led_path|real_path
            local ledPath, realPath = trimmed:match("^([^|]+)|(.+)$")
            if ledPath and realPath then
                -- Only accept Sony/PlayStation controllers
                local lowerReal = string.lower(realPath)
                local isSony = lowerReal:find("sony") or lowerReal:find("playstation")
                    or lowerReal:find("054c") or lowerReal:find("ps%-controller")
                if isSony then
                    local isDoubleColon = ledPath:find("::red", 1, true)
                    local sep
                    if isDoubleColon then
                        sep = "::"
                    else
                        sep = ":"
                    end
                    -- Strip trailing separator + "red" to get base path
                    local basePath
                    if isDoubleColon then
                        basePath = ledPath:match("^(.+)::red$")
                    else
                        basePath = ledPath:match("^(.+):red$")
                    end
                    if basePath and basePath ~= "" then
                        newControllers[basePath] = { separator = sep }
                        newCount = newCount + 1
                    end
                end
            end
        end
    end

    -- Detect changes
    local changed = (newCount ~= controllerCount)
    if not changed then
        for k in pairs(newControllers) do
            if not controllers[k] then
                changed = true
                break
            end
        end
    end

    local wasEmpty = (controllerCount == 0)
    controllers = newControllers
    controllerCount = newCount

    noctalia.state.set("controllerCount", controllerCount)
    noctalia.state.set("hasController", controllerCount > 0)

    if controllerCount > 0 then
        scanBattery()
        -- Auto-apply color on newly connected controller
        if changed and not wasEmpty == false then
            applyConfigColor()
        end
    else
        batteryLevel = -1
        noctalia.state.set("batteryLevel", -1)
    end
end

-- Run scan_controllers.sh and parse result
local function scanControllers()
    local cmd = "sh " .. pluginDir .. "/scripts/scan_controllers.sh"
    noctalia.runAsync(cmd, function(res)
        parseScanOutput(res.stdout or "")
    end)
end

-- Watch for commands from widget (e.g. "setColor:R:G:B" or "scan")
noctalia.state.watch("command", function(cmd)
    if not cmd or cmd == "" then
        return
    end

    if cmd == "scan" then
        scanControllers()
    else
        -- "setColor:R:G:B"
        local rStr, gStr, bStr = cmd:match("^setColor:(%d+):(%d+):(%d+)$")
        if rStr then
            local r = tonumber(rStr) or 0
            local g = tonumber(gStr) or 0
            local b = tonumber(bStr) or 0
            applyColorToAll(r, g, b)
        end
    end

    -- Clear command after handling
    noctalia.state.set("command", "")
end)

-- Periodic update: scan for controllers and battery
function update()
    scanControllers()
end

-- Initial scan on startup
scanControllers()
