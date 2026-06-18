-- service.luau
-- Background service for not-just-text plugin.
-- Handles fortune, list, and static text modes.
-- Communicates display text to the widget via noctalia.state.

noctalia.setUpdateInterval(0)

local MAX_RETRIES = 10
local retries = 0

local function getSettings()
    local s = noctalia.settings
    return {
        fortuneEnabled  = s.fortuneEnabled  or false,
        fortuneOffensive = s.fortuneOffensive or false,
        fortuneEqual    = s.fortuneEqual    or false,
        fortuneCategory = s.fortuneCategory  or "",
        fortuneMaxLength = s.fortuneMaxLength or 60,
        listEnabled     = s.listEnabled     or false,
        textFile        = s.textFile        or "",
        text            = s.text            or "Hello",
    }
end

-- Build the fortune command as a shell string
local function buildFortuneCmd(cfg)
    local cmd = "fortune -s"
    if cfg.fortuneOffensive then
        cmd = cmd .. " -o"
    end
    if cfg.fortuneEqual then
        cmd = cmd .. " -e"
    end
    local cat = cfg.fortuneCategory
    if type(cat) == "string" and #cat > 0 then
        cmd = cmd .. " " .. cat
    end
    return cmd
end

-- Attempt to get a short single-line fortune (with retry logic)
local function tryFortune(cfg, attempt)
    local cmd = buildFortuneCmd(cfg)
    noctalia.runAsync(cmd, function(output, exitCode)
        if exitCode == 127 then
            noctalia.state.set("displayText", "fortune not installed")
            return
        end
        if exitCode ~= 0 then
            noctalia.state.set("displayText", "fortune error")
            return
        end
        -- Strip leading/trailing whitespace and split into lines
        local trimmed = output:match("^%s*(.-)%s*$")
        -- Check for exactly one non-empty line
        local lineCount = 0
        local singleLine = ""
        for line in (trimmed .. "\n"):gmatch("([^\n]*)\n") do
            local l = line:match("^%s*(.-)%s*$")
            if #l > 0 then
                lineCount = lineCount + 1
                singleLine = l
            end
        end
        local maxLen = cfg.fortuneMaxLength
        if lineCount == 1 and #singleLine <= maxLen then
            noctalia.state.set("displayText", singleLine)
        elseif attempt < MAX_RETRIES then
            tryFortune(cfg, attempt + 1)
        else
            noctalia.state.set("displayText", "(╯°□°）╯︵ ┻━┻")
        end
    end)
end

-- Pick a random non-comment line from a text file
local function pickFromList(cfg)
    local pluginDir = noctalia.pluginDir or ""
    local filePath = cfg.textFile
    if type(filePath) ~= "string" or #filePath == 0 then
        filePath = pluginDir .. "/examples.txt"
    end
    local content = noctalia.readFile(filePath)
    if not content then
        noctalia.state.set("displayText", cfg.text or "Hello")
        return
    end
    local lines = {}
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        local l = line:match("^%s*(.-)%s*$")
        -- Ignore empty lines and comment lines starting with "# "
        if #l > 0 and l:sub(1, 2) ~= "# " then
            lines[#lines + 1] = l
        end
    end
    if #lines > 0 then
        local idx = math.random(1, #lines)
        noctalia.state.set("displayText", lines[idx])
    else
        noctalia.state.set("displayText", cfg.text or "Hello")
    end
end

-- Main refresh function
local function refresh()
    local cfg = getSettings()
    if cfg.fortuneEnabled then
        tryFortune(cfg, 0)
    elseif cfg.listEnabled then
        pickFromList(cfg)
    else
        noctalia.state.set("displayText", cfg.text or "Hello")
    end
end

-- Watch for refresh commands from the widget
noctalia.state.watch("command", function(value)
    if value == "refresh" then
        noctalia.state.set("command", "")
        refresh()
    end
end)

-- IPC event handler
function onIpc(event)
    if event == "refresh" then
        refresh()
    end
end

-- Initialise on startup
refresh()
