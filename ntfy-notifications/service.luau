-- ntfy-notifications: service.luau
-- Polls the ntfy API via curl and publishes state for the bar widget.
-- Uses standard Lua syntax only (no +=, no backtick strings).

local serverUrl    = noctalia.settings.get("serverUrl")    or "https://ntfy.sh"
local topics       = noctalia.settings.get("topics")       or ""
local authMethod   = noctalia.settings.get("authMethod")   or "none"
local authToken    = noctalia.settings.get("authToken")    or ""
local authUsername = noctalia.settings.get("authUsername") or ""
local authPassword = noctalia.settings.get("authPassword") or ""
local pollInterval = noctalia.settings.get("pollInterval") or 30
local maxMessages  = noctalia.settings.get("maxMessages")  or 100

-- Clamp poll interval to a sensible minimum
if pollInterval < 10 then
    pollInterval = 10
end

-- Internal state
local messageCount  = 0
local lastMessage   = ""
local lastTimestamp = 0
local seenIds       = {}

-- Strip trailing slashes from server URL
local function trimTrailingSlash(s)
    while #s > 0 and s:sub(-1) == "/" do
        s = s:sub(1, -2)
    end
    return s
end

-- Build a cleaned comma-separated topic string
local function cleanTopics(raw)
    local result = {}
    for part in raw:gmatch("[^,]+") do
        local t = part:match("^%s*(.-)%s*$")
        if #t > 0 then
            result[#result + 1] = t
        end
    end
    return table.concat(result, ",")
end

-- Simple URL-encode (ntfy topics are typically alphanumeric/dash/underscore)
local function urlEncode(s)
    return s:gsub("[^%w%-_%.~,]", function(c)
        return string.format("%%%02X", c:byte())
    end)
end

-- Parse a single NDJSON response from ntfy and update state
local function parseResponse(output)
    local newMessages = 0
    local newestTitle = ""
    local latestTs    = lastTimestamp

    for line in output:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if #line > 0 then
            -- Extract event field
            local event = line:match('"event"%s*:%s*"([^"]*)"')
            if event == "message" then
                local id    = line:match('"id"%s*:%s*"([^"]*)"')   or ""
                local ts    = tonumber(line:match('"time"%s*:%s*(%d+)')) or 0
                local title = line:match('"title"%s*:%s*"([^"]*)"') or ""
                local msg   = line:match('"message"%s*:%s*"([^"]*)"') or ""

                if id ~= "" and not seenIds[id] then
                    seenIds[id] = true
                    newMessages = newMessages + 1
                    if ts > latestTs then
                        latestTs    = ts
                        newestTitle = title ~= "" and title or msg
                    end
                end
            end
        end
    end

    if latestTs > lastTimestamp then
        lastTimestamp = latestTs
    end

    if newMessages > 0 then
        messageCount = messageCount + newMessages
        -- Cap at maxMessages
        if messageCount > maxMessages then
            messageCount = maxMessages
        end
        if newestTitle ~= "" then
            lastMessage = newestTitle
        end
        noctalia.state.set("messageCount", messageCount)
        noctalia.state.set("lastMessage",  lastMessage)
    end
end

-- Build and run the curl command for one poll cycle
local function poll()
    local cleaned = cleanTopics(topics)
    if #cleaned == 0 then
        -- No topics configured; publish zeros and return
        noctalia.state.set("messageCount", 0)
        noctalia.state.set("lastMessage",  "")
        noctalia.state.set("error", "no_topics")
        return
    end

    local base = trimTrailingSlash(serverUrl)
    local url  = base .. "/" .. urlEncode(cleaned) .. "/json?poll=1"

    if lastTimestamp > 0 then
        url = url .. "&since=" .. tostring(lastTimestamp + 1)
    else
        -- First poll: fetch last 24 hours
        local since = os.time() - 86400
        url = url .. "&since=" .. tostring(since)
    end

    -- Build curl command
    local cmd = "curl -s --max-time 15"

    if authMethod == "token" and #authToken > 0 then
        cmd = cmd .. " -H 'Authorization: Bearer " .. authToken .. "'"
    elseif authMethod == "basic" and #authUsername > 0 then
        -- base64-encode user:pass via shell
        local creds = authUsername .. ":" .. authPassword
        cmd = cmd .. " -u '" .. creds .. "'"
    end

    cmd = cmd .. " '" .. url .. "'"

    noctalia.runAsync(cmd, function(output, exitCode)
        if exitCode ~= 0 then
            noctalia.state.set("error", "curl_failed_" .. tostring(exitCode))
            return
        end
        noctalia.state.set("error", "")
        parseResponse(output)
    end)
end

-- Watch for manual refresh commands from the widget
noctalia.state.watch("command", function(cmd)
    if cmd == "refresh" then
        poll()
    elseif cmd == "reset" then
        messageCount  = 0
        lastMessage   = ""
        lastTimestamp = 0
        seenIds       = {}
        noctalia.state.set("messageCount", 0)
        noctalia.state.set("lastMessage",  "")
        poll()
    end
end)

-- Set poll interval and kick off the first poll
noctalia.setUpdateInterval(pollInterval * 1000)

-- update() is called on each interval tick
function update()
    poll()
end
