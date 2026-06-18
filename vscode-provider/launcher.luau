-- VS Code Provider — launcher provider.
-- Search recently opened VS Code workspaces and folders, and open them in VS Code.

local home = os.getenv("HOME") or "/tmp"
local stateDir = `{home}/.cache/noctalia/plugins/vscode-provider`
local statePath = `{stateDir}/state.json`

local openCounts = {}
local stateLoaded = false
local database = {}
local dbLoaded = false
local dbLoading = false

local function loadState(callback)
  noctalia.runAsync(`test -f '{statePath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`cat '{statePath}'`, function(catRes)
        local success, parsed = pcall(noctalia.json.decode, catRes.stdout or catRes.body or "")
        if success and type(parsed) == "table" and type(parsed.openCounts) == "table" then
          openCounts = parsed.openCounts
        end
        stateLoaded = true
        if callback then callback() end
      end)
    else
      stateLoaded = true
      if callback then callback() end
    end
  end)
end

local function saveState()
  if not stateLoaded then return end
  local payload = noctalia.json.encode({ openCounts = openCounts })
  noctalia.runAsync(`mkdir -p '{stateDir}'`, function()
    local escaped = payload:gsub("'", "'\\''")
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{escaped}' '{statePath}'`)
  end)
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function urlDecode(s)
  s = s:gsub("+", " ")
  s = s:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return s
end

local function deslugify(slug)
  local words = {}
  for w in slug:gmatch("[^-]+") do
    table.insert(words, w:sub(1,1):upper() .. w:sub(2))
  end
  return table.concat(words, " ")
end

local function displayNameFromFolder(fullname)
  local finalPart = fullname:match("([^/]+)$") or fullname
  if fullname:find("vscode-remote://", 1, true) == 1 then
    local tail = fullname:sub(17)
    local plusIdx = tail:find("+", 1, true)
    if plusIdx then
      local rtype = tail:sub(1, plusIdx - 1)
      local rpath = tail:sub(plusIdx + 1)
      if rtype == "ssh-remote" then
        local slashIdx = rpath:find("/", 1, true)
        local host = if slashIdx then rpath:sub(1, slashIdx - 1) else rpath
        return `{finalPart} [SSH: {host}]`
      else
        return `{finalPart} [{deslugify(rtype)}]`
      end
    end
  end
  return finalPart
end

local function displayNameFromWorkspace(fullname)
  local name = fullname:match("([^/]+)$") or fullname
  return name:gsub("%.code%-workspace$", "") .. " (Workspace)"
end

local function tr(key, replacements)
  local val = noctalia.tr(key) or key
  if replacements then
    for k, v in replacements do
      val = val:gsub("{" .. k .. "}", tostring(v))
    end
  end
  return val
end

local function loadWorkspaces(callback)
  if dbLoading then return end
  dbLoading = true
  dbLoaded = false

  local configName = launcher.getConfig("configName") or "Code"
  local baseConfig = os.getenv("XDG_CONFIG_HOME") or `{home}/.config`
  local workspaceDir = `{baseConfig}/{configName}/User/workspaceStorage`

  local cmd = `bash -c 'for f in $(ls -1t "{workspaceDir}"/*/workspace.json 2>/dev/null); do echo "=== $f ==="; cat "$f"; done'`
  noctalia.runAsync(cmd, function(res)
    local list = {}
    if res.exitCode == 0 then
      local currentFile = nil
      local currentContent = {}
      
      local function processEntry()
        if currentFile and #currentContent > 0 then
          local body = table.concat(currentContent, "\n")
          local success, parsed = pcall(noctalia.json.decode, body)
          if success and type(parsed) == "table" then
            local uri = parsed.workspace or parsed.folder
            if uri then
              local isWorkspace = parsed.workspace ~= nil
              local detail = urlDecode(uri):gsub("^file://", "")
              local displayName = if isWorkspace then displayNameFromWorkspace(detail) else displayNameFromFolder(detail)
              table.insert(list, {
                fullPath = currentFile,
                uri = uri,
                detail = detail,
                displayName = displayName,
                isWorkspace = isWorkspace
              })
            end
          end
        end
      end

      for line in (res.stdout or res.body or ""):gmatch("[^\r\n]+") do
        if line:find("^=== ") then
          processEntry()
          currentFile = line:match("^=== (.*) ===$")
          currentContent = {}
        else
          table.insert(currentContent, line)
        end
      end
      processEntry()
    end

    database = list
    dbLoaded = true
    dbLoading = false
    if callback then callback() end
  end)
end

-- Initialize database load
loadWorkspaces()

function onQuery(query)
  local filter = trim(query)
  local isCommandMode = filter:find("^>vsc") ~= nil
  
  local includeInSearch = launcher.getConfig("includeInSearch") ~= false
  if not isCommandMode and not includeInSearch then
    launcher.setResults(query, {})
    return
  end

  local searchWord = filter
  if isCommandMode then
    searchWord = filter:gsub("^>vsc%s*", "")
  end

  if not dbLoaded then
    if dbLoading then
      launcher.setResults(query, {
        {
          id = "loading",
          title = tr("launcher.loading.title"),
          subtitle = tr("launcher.loading.description"),
          glyph = "loader"
        }
      })
    else
      launcher.setResults(query, {
        {
          id = "error",
          title = tr("launcher.error.title"),
          subtitle = tr("launcher.error.description"),
          glyph = "alert-circle"
        }
      })
    end
    return
  end

  loadState(function()
    local matched = {}
    local q = searchWord:lower()

    for _, entry in database do
      if q == "" or entry.displayName:lower():find(q, 1, true) or entry.detail:lower():find(q, 1, true) then
        table.insert(matched, entry)
      end
    end

    if #matched == 0 then
      launcher.setResults(query, {})
      return
    end

    -- Sort rest by open frequency count
    if #matched > 1 then
      local first = matched[1]
      local rest = {}
      for i = 2, #matched do
        table.insert(rest, matched[i])
      end
      table.sort(rest, function(a, b)
        local countA = openCounts[a.fullPath] or 0
        local countB = openCounts[b.fullPath] or 0
        return countA > countB
      end)
      matched = { first }
      for _, r in rest do
        table.insert(matched, r)
      end
    end

    local results = {}
    for _, entry in matched do
      local command = launcher.getConfig("command") or "code"
      table.insert(results, {
        id = `ws:{entry.isWorkspace and "true" or "false"}:{entry.uri}:{entry.fullPath}`,
        title = entry.displayName,
        subtitle = entry.detail,
        glyph = command,
        badgeIcon = "folder-open"
      })
    end

    launcher.setResults(query, results)
  end)
end

function onActivate(id)
  if id:find("ws:", 1, true) == 1 then
    local isWorkspaceStr, uri, fullPath = id:match("^ws:([^:]+):([^:]+):(.*)$")
    if uri and fullPath then
      local isWorkspace = isWorkspaceStr == "true"
      openCounts[fullPath] = (openCounts[fullPath] or 0) + 1
      saveState()

      local command = launcher.getConfig("command") or "code"
      local option = if isWorkspace then "--file-uri" else "--folder-uri"
      local escapedUri = uri:gsub("'", "'\\''")
      
      noctalia.runAsync(`{command} {option} '{escapedUri}'`)
    end
  end
end
