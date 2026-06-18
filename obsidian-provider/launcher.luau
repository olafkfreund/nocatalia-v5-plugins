-- Obsidian Provider — launcher provider.
-- Switch between Obsidian vaults from the launcher.

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function urlEncode(s)
  return (s:gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
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
  local isCommandMode = filter:find("^>obs") ~= nil

  local includeInSearch = launcher.getConfig("includeInSearch") ~= false
  if not isCommandMode and not includeInSearch then
    launcher.setResults(query, {})
    return
  end

  local searchWord = filter
  if isCommandMode then
    searchWord = filter:gsub("^>obs%s*", "")
  end
  searchWord = trim(searchWord):lower()

  local configPathSetting = launcher.getConfig("obsidianConfigPath") or "~/.config/obsidian/obsidian.json"
  local configPath = noctalia.expandPath(configPathSetting)

  local content = noctalia.readFile(configPath)
  if not content or content == "" then
    launcher.setResults(query, {
      {
        id = "error",
        title = tr("launcher.error.name"),
        subtitle = tr("launcher.error.description"),
        glyph = "alert-circle"
      }
    })
    return
  end

  local success, parsed = pcall(noctalia.json.decode, content)
  if not success or type(parsed) ~= "table" or type(parsed.vaults) ~= "table" then
    launcher.setResults(query, {
      {
        id = "error",
        title = tr("launcher.error.name"),
        subtitle = tr("launcher.error.description"),
        glyph = "alert-circle"
      }
    })
    return
  end

  local vaults = {}
  for id, v in pairs(parsed.vaults) do
    if type(v) == "table" and type(v.path) == "string" then
      local path = v.path
      local name = path:match("([^/]+)$") or path
      table.insert(vaults, {
        id = id,
        path = path,
        displayName = name,
        ts = v.ts or 0,
        isOpen = not not v.open
      })
    end
  end

  table.sort(vaults, function(a, b)
    return a.ts > b.ts
  end)

  local results = {}
  for _, entry in ipairs(vaults) do
    if searchWord == "" or entry.displayName:lower():find(searchWord, 1, true) or entry.path:lower():find(searchWord, 1, true) then
      local badge = ""
      if entry.isOpen then
        badge = "circle-dot"
      end
      table.insert(results, {
        id = "vault:" .. entry.displayName,
        title = entry.displayName,
        subtitle = entry.path,
        glyph = "obsidian",
        badgeIcon = badge
      })
    end
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id:find("vault:", 1, true) == 1 then
    local displayName = id:match("^vault:(.*)$")
    if displayName then
      local uri = "obsidian://open?vault=" .. urlEncode(displayName)
      noctalia.runAsync("xdg-open '" .. uri:gsub("'", "'\\''") .. "'")
    end
  end
end
