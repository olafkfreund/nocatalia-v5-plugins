-- RSS Feed — background service.
-- Fetches RSS feeds via curl and tracks unread item counts.

local totalItems = 0
local unreadCount = 0
local latestTitle = ""
local latestFeed = ""

-- Simple persistent read-item tracking via state
local readItems = {}

local function updateState()
  noctalia.state.set("totalItems", totalItems)
  noctalia.state.set("unreadCount", unreadCount)
  noctalia.state.set("latestTitle", latestTitle)
  noctalia.state.set("latestFeed", latestFeed)
end

local function parseRss(xmlText)
  local items = {}
  -- Extract <title> and <link> from <item> blocks
  for itemBlock in xmlText:gmatch("<item[^>]*>(.-)</item>") do
    local title = itemBlock:match("<title><!%[CDATA%[(.-)%]%]></title>")
                or itemBlock:match("<title>(.-)</title>")
    local link = itemBlock:match("<link>(.-)</link>")
                or itemBlock:match("<guid>(.-)</guid>")
    title = title and title:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">") or ""
    link = link or ""
    if title ~= "" then
      items[#items + 1] = {title = title, link = link}
    end
  end
  return items
end

local function fetchFeed(url, onDone)
  local maxItems = tonumber(noctalia.getConfig("maxItemsPerFeed")) or 10
  noctalia.runAsync("curl -s --max-time 10 -L " .. url .. " 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      if onDone then onDone({}) end
      return
    end
    local text = res.stdout or res.body or ""
    local items = parseRss(text)
    -- Trim to maxItems
    local result = {}
    for i = 1, math.min(#items, maxItems) do
      result[i] = items[i]
    end
    if onDone then onDone(result) end
  end)
end

local function refreshFeeds()
  local feedsConfig = noctalia.getConfig("feeds") or ""
  if feedsConfig == "" then
    updateState()
    return
  end

  local urls = {}
  for url in feedsConfig:gmatch("[^,]+") do
    local trimmed = url:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed ~= "" then
      urls[#urls + 1] = trimmed
    end
  end

  if #urls == 0 then
    updateState()
    return
  end

  local allItems = {}
  local pending = #urls
  local firstTitle = ""
  local firstFeed = ""

  local function onFeedDone(items, feedUrl)
    for _, item in ipairs(items) do
      allItems[#allItems + 1] = {title = item.title, link = item.link, feed = feedUrl}
    end
    pending = pending - 1
    if pending == 0 then
      totalItems = #allItems
      -- Count unread
      local unread = 0
      for _, item in ipairs(allItems) do
        if not readItems[item.link] then
          unread = unread + 1
          if firstTitle == "" then
            firstTitle = item.title
            firstFeed = item.feed
          end
        end
      end
      unreadCount = unread
      latestTitle = firstTitle
      latestFeed = firstFeed
      updateState()
    end
  end

  for _, url in ipairs(urls) do
    local feedUrl = url
    fetchFeed(feedUrl, function(items)
      onFeedDone(items, feedUrl)
    end)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refreshFeeds()
  elseif cmd and cmd:sub(1, 9) == "markRead:" then
    local link = cmd:sub(10)
    readItems[link] = true
    unreadCount = math.max(0, unreadCount - 1)
    updateState()
  elseif cmd == "markAllRead" then
    readItems = {}
    for i = 1, totalItems do
      unreadCount = 0
    end
    updateState()
  end
end)

-- Initial fetch
refreshFeeds()

local interval = (tonumber(noctalia.getConfig("updateInterval")) or 600) * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refreshFeeds()
end
