-- Habitica — background service.
-- Fetches daily tasks and todos via Habitica API using curl.

local userId = ""
local apiToken = ""
local dueDailies = 0
local dueTodos = 0
local xp = 0
local hp = 0
local configured = false

local function updateState()
  noctalia.state.set("dueDailies", dueDailies)
  noctalia.state.set("dueTodos", dueTodos)
  noctalia.state.set("xp", xp)
  noctalia.state.set("hp", hp)
  noctalia.state.set("configured", configured)
end

local function apiCall(path, callback)
  local cmd = 'curl -sS --max-time 30 -H "x-api-user: ' .. userId
    .. '" -H "x-api-key: ' .. apiToken
    .. '" "https://habitica.com/api/v3' .. path .. '" 2>/dev/null'
  noctalia.runAsync(cmd, callback)
end

local function refresh()
  userId = noctalia.getConfig("habiticaUserId") or ""
  apiToken = noctalia.getConfig("habiticaApiToken") or ""

  if userId == "" or apiToken == "" then
    configured = false
    updateState()
    return
  end
  configured = true

  -- Fetch user stats
  apiCall("/user?userFields=stats", function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    local hpVal = text:match('"hp":([%d%.]+)')
    local xpVal = text:match('"exp":([%d%.]+)')
    if hpVal then hp = tonumber(hpVal) or 0 end
    if xpVal then xp = tonumber(xpVal) or 0 end
    updateState()
  end)

  -- Fetch dailies due
  apiCall("/tasks/user?type=dailys", function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    local count = 0
    for _ in text:gmatch('"isDue":true') do
      count = count + 1
    end
    for _ in text:gmatch('"completed":true') do
      count = count - 1
    end
    dueDailies = math.max(0, count)
    updateState()
  end)

  -- Fetch todos
  apiCall("/tasks/user?type=todos", function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    local count = 0
    for _ in text:gmatch('"completed":false') do
      count = count + 1
    end
    dueTodos = count
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  end
end)

refresh()

local interval = (tonumber(noctalia.getConfig("refreshInterval")) or 15) * 60 * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
