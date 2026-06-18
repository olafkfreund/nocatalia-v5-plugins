-- SSH Sessions — launcher provider.
-- Switch or open SSH sessions from the launcher.

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function tr(key, replacements)
  local val = noctalia.tr(key) or key
  if replacements then
    for k, v in pairs(replacements) do
      val = val:gsub("{" .. k .. "}", tostring(v))
    end
  end
  return val
end

function onQuery(query)
  local filter = trim(query)
  local isCommandMode = filter:find("^>ssh") ~= nil

  -- Since it is a global search provider, it should always display if searched, unless configured otherwise.
  local searchWord = filter
  if isCommandMode then
    searchWord = filter:gsub("^>ssh%s*", "")
  end
  searchWord = trim(searchWord):lower()

  local hosts = noctalia.state.get("hosts") or {}
  local results = {}

  for _, entry in ipairs(hosts) do
    local host = entry.host
    if host and host.name then
      local nameLower = host.name:lower()
      local hostnameLower = (host.hostname or ""):lower()
      local userLower = (host.user or ""):lower()

      if searchWord == "" or nameLower:find(searchWord, 1, true) or hostnameLower:find(searchWord, 1, true) or userLower:find(searchWord, 1, true) then
        local desc = ""
        if host.user and host.user ~= "" then
          desc = host.user .. "@"
        end
        desc = desc .. (host.hostname ~= "" and host.hostname or host.name)
        if host.port and host.port ~= "" and host.port ~= "22" then
          desc = desc .. ":" .. host.port
        end

        local badge = ""
        if entry.isActive then
          badge = "circle-check"
        end

        table.insert(results, {
          id = "host:" .. host.name,
          title = host.name,
          subtitle = desc,
          glyph = "terminal",
          badgeIcon = badge
        })
      end
    end
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id:find("host:", 1, true) == 1 then
    local hostName = id:match("^host:(.*)$")
    if hostName and hostName ~= "" then
      noctalia.runInTerminal("ssh " .. hostName)
    end
  end
end
