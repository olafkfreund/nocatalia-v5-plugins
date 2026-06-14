-- GitHub Feed — launcher provider.
-- Lists and filters unread notifications and feed events.

local notifications = {}
local feedEvents = {}

local function openUrl(url)
  noctalia.runAsync(`xdg-open '{url}'`)
end

local function formatTimeAgo(timeStr)
  local y, m, d, hh, mm = timeStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if y then
    return `{y}/{m}/{d} {hh}:{mm}`
  end
  return timeStr
end

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  -- Format notifications
  for _, n in notifications do
    local title = n.subject and n.subject.title or "Notification"
    local repo = n.repository and n.repository.full_name or ""
    local type = n.subject and n.subject.type or ""
    local url = n.url or ""

    if filter == "" or title:lower():find(filter) or repo:lower():find(filter) then
      table.insert(results, {
        id = url,
        title = `🔔 {repo}: {title}`,
        subtitle = `Type: {type} — Press Enter to open`,
        glyph = "bell",
      })
    end
  end

  -- Format feed events
  for i, e in feedEvents do
    local actor = e.actor and e.actor.login or "Someone"
    local repo = e.repo and e.repo.name or ""
    local type = e.type or ""
    local createdAt = e.created_at or ""
    
    local title = ""
    local url = ""

    if type == "WatchEvent" then
      title = `⭐ {actor} starred {repo}`
      url = `https://github.com/{repo}`
    elseif type == "ForkEvent" then
      local forkee = e.payload and e.payload.forkee and e.payload.forkee.full_name or ""
      title = `🍴 {actor} forked {repo} to {forkee}`
      url = `https://github.com/{forkee}`
    elseif type == "PullRequestEvent" then
      local prTitle = e.payload and e.payload.pull_request and e.payload.pull_request.title or ""
      local prUrl = e.payload and e.payload.pull_request and e.payload.pull_request.html_url or ""
      local action = e.payload and e.payload.action or "opened"
      title = `🔀 {actor} {action} PR in {repo}: {prTitle}`
      url = prUrl
    elseif type == "CreateEvent" then
      title = `📦 {actor} created repository {repo}`
      url = `https://github.com/{repo}`
    else
      title = `GitHub Event ({type}) by {actor} on {repo}`
      url = `https://github.com/{repo}`
    end

    if filter == "" or title:lower():find(filter) or actor:lower():find(filter) or repo:lower():find(filter) then
      table.insert(results, {
        id = url,
        title = title,
        subtitle = `Activity at {formatTimeAgo(createdAt)} — Press Enter to open`,
        glyph = "brand-github",
      })
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "empty",
      title = "No GitHub activity",
      subtitle = "No notifications or feed events found.",
      glyph = "alert-circle",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id and id:find("^http") == 1 then
    openUrl(id)
  end
end

-- Watch for updates to keep results fresh
noctalia.state.watch("notifications", function(val)
  notifications = if type(val) == "table" then val else {}
end)

noctalia.state.watch("feed_events", function(val)
  feedEvents = if type(val) == "table" then val else {}
end)
