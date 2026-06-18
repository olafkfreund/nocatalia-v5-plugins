-- syncthing-status: service.luau
-- Background service that polls the Syncthing API via syncthing-status.py
-- and publishes state keys for the bar widget to consume.

local pluginDir = noctalia.pluginDir

-- Read settings with defaults
local cfg = noctalia.config
local pollIntervalMs = cfg.pollIntervalMs or 10000
local enabled       = cfg.enabled
if enabled == nil then enabled = true end

local apiUrl      = cfg.apiUrl    or ""
local apiKey      = cfg.apiKey    or ""
local configPath  = cfg.configPath or ""
local verifyTls   = cfg.verifyTls
if verifyTls == nil then verifyTls = false end
local folderIds   = cfg.folderIds or ""

-- Initialise shared state
noctalia.state.set("syncState",        "unconfigured")
noctalia.state.set("detail",           "")
noctalia.state.set("syncingCount",     0)
noctalia.state.set("errorCount",       0)
noctalia.state.set("connectedDevices", 0)

-- Set update interval
noctalia.setUpdateInterval(pollIntervalMs)

-- Build the command arguments table
local function buildCommand()
    local args = {"python3", pluginDir .. "/syncthing-status.py"}

    if apiUrl ~= "" then
        args[#args + 1] = "--url"
        args[#args + 1] = apiUrl
    end

    if apiKey ~= "" then
        args[#args + 1] = "--api-key"
        args[#args + 1] = apiKey
    end

    if not verifyTls then
        args[#args + 1] = "--no-verify-tls"
    end

    if configPath ~= "" then
        args[#args + 1] = "--config"
        args[#args + 1] = configPath
    end

    if folderIds ~= "" then
        args[#args + 1] = "--folders"
        args[#args + 1] = folderIds
    end

    return args
end

-- Parse the JSON output from the Python helper and push state
local function handleOutput(output)
    local text = output or ""
    -- Trim whitespace
    text = text:match("^%s*(.-)%s*$")
    if text == "" then
        noctalia.state.set("syncState", "error")
        noctalia.state.set("detail", "Empty response from helper script")
        return
    end

    -- Basic JSON field extraction using pattern matching
    -- (Luau does not have a built-in JSON library; use noctalia.json if available,
    --  otherwise fall back to pattern-based extraction)
    local ok, parsed = pcall(function()
        return noctalia.json.decode(text)
    end)

    if ok and parsed then
        local state            = parsed.state            or "unconfigured"
        local detail           = parsed.detail           or ""
        local syncingFolders   = 0
        local erroredFolders   = 0
        local connectedDevices = 0

        if parsed.totals then
            syncingFolders = parsed.totals.syncingFolders or 0
            erroredFolders = parsed.totals.erroredFolders or 0
        end

        if parsed.devices then
            connectedDevices = parsed.devices.connected or 0
        end

        noctalia.state.set("syncState",        state)
        noctalia.state.set("detail",           detail)
        noctalia.state.set("syncingCount",     syncingFolders)
        noctalia.state.set("errorCount",       erroredFolders)
        noctalia.state.set("connectedDevices", connectedDevices)
    else
        -- Fallback: extract state field with a simple pattern
        local state = text:match('"state"%s*:%s*"([^"]+)"') or "error"
        local detail = text:match('"detail"%s*:%s*"([^"]+)"') or "Failed to parse helper output"
        noctalia.state.set("syncState", state)
        noctalia.state.set("detail",   detail)
        noctalia.state.set("syncingCount",     0)
        noctalia.state.set("errorCount",       0)
        noctalia.state.set("connectedDevices", 0)
    end
end

-- Called by Noctalia on each update tick
function update()
    if not enabled then
        noctalia.state.set("syncState", "disabled")
        noctalia.state.set("detail",    "Monitoring is disabled")
        return
    end

    local cmd = buildCommand()
    noctalia.runAsync(cmd, function(output, exitCode)
        if exitCode ~= 0 and (output == nil or output:match("^%s*$")) then
            noctalia.state.set("syncState", "error")
            noctalia.state.set("detail",    "Helper exited with code " .. tostring(exitCode))
            noctalia.state.set("syncingCount",     0)
            noctalia.state.set("errorCount",       0)
            noctalia.state.set("connectedDevices", 0)
        else
            handleOutput(output)
        end
    end)
end

-- Watch for external refresh commands (e.g. noctalia msg …)
noctalia.state.watch("command", function(cmd)
    if cmd == "refresh" then
        update()
    end
end)
