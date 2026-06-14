-- GitHub Feed — background service.
-- Periodically fetches notifications and feed events.

noctalia.setUpdateInterval(5000) -- Check check-interval every 5 seconds

local lastFetchTime = 0
local notifications = {}
local feedEvents = {}
local username = ""
local token = ""
local githubUrl = ""
local refreshInterval = 1800
local maxEvents = 50

local function getApiUrl(endpoint)
  local baseUrl = "https://api.github.com"
  if githubUrl ~= "" then
    local host = githubUrl:gsub("^https?://", ""):gsub("/+$", "")
    baseUrl = `https://{host}/api/v3`
  end
  return baseUrl .. endpoint
end

local function fetchNotifications()
  if token == "" then return end
  local url = getApiUrl("/notifications")
  noctalia.http({
    url = url,
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Accept"] = "application/vnd.github.v3+json",
      ["User-Agent"] = "Noctalia-Shell"
    }
  }, function(res)
    if not res.ok then
      noctalia.log(`GitHub Feed: failed to fetch notifications. Status: {res.status}`)
      return
    end

    local data = noctalia.json.decode(res.body)
    if type(data) == "table" then
      notifications = data
      noctalia.state.set("notification_count", #notifications)
      noctalia.state.set("notifications", notifications)
    end
  end)
end

local function fetchFeed()
  if username == "" then return end
  local url = getApiUrl(`/users/{username}/received_events`)
  local headers = {
    ["Accept"] = "application/vnd.github.v3+json",
    ["User-Agent"] = "Noctalia-Shell"
  }
  if token ~= "" then
    headers["Authorization"] = "Bearer " .. token
  end

  noctalia.http({
    url = url,
    headers = headers
  }, function(res)
    if not res.ok then
      noctalia.log(`GitHub Feed: failed to fetch feed. Status: {res.status}`)
      return
    end

    local data = noctalia.json.decode(res.body)
    if type(data) == "table" then
      local events = {}
      for i = 1, math.min(#data, maxEvents) do
        table.insert(events, data[i])
      end
      feedEvents = events
      noctalia.state.set("feed_events", feedEvents)
    end
  end)
end

local function poll()
  local now = os.clock()
  username = noctalia.getConfig("username") or ""
  token = noctalia.getConfig("token") or ""
  githubUrl = noctalia.getConfig("github_url") or ""
  refreshInterval = noctalia.getConfig("refresh_interval") or 1800
  maxEvents = noctalia.getConfig("max_events") or 50

  if username == "" and token == "" then
    return
  end

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    noctalia.state.set("is_loading", true)
    
    fetchNotifications()
    fetchFeed()

    noctalia.state.set("is_loading", false)
    noctalia.state.set("last_fetch_timestamp", os.time())
  end
end

-- Allow manual refresh via command channel
noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    lastFetchTime = 0
    poll()
  end
end)

function update()
  poll()
end
