-- Zed Provider — launcher provider.
-- Browse local directories or search recent Zed projects, and open them in Zed.

local home = os.getenv("HOME") or "/tmp"
local dbPath = `{home}/.local/share/zed/db/0-stable/db.sqlite`
local stateDir = `{home}/.cache/noctalia/plugins/zed-provider`
local statePath = `{stateDir}/state.json`

local openCounts = {}
local stateLoaded = false
local zedInstalled = false
local zedBin = "zed"

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

local function checkZedInstalled(callback)
  noctalia.runAsync("(command -v zeditor >/dev/null 2>&1 && echo zeditor) || (command -v zed >/dev/null 2>&1 && echo zed) || echo notfound", function(res)
    local bin = (res.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if bin ~= "notfound" and bin ~= "" then
      zedBin = bin
      zedInstalled = true
    else
      zedInstalled = false
    end
    callback()
  end)
end

local function getRecentProjects(callback)
  noctalia.runAsync(`sqlite3 '{dbPath}' "SELECT paths, timestamp FROM workspaces WHERE paths != '' AND paths IS NOT NULL ORDER BY timestamp DESC;"`, function(res)
    local list = {}
    if res.exitCode == 0 then
      for line in (res.stdout or res.body or ""):gmatch("[^\r\n]+") do
        local pipeIdx = line:find("|", 1, true)
        if pipeIdx then
          local path = line:sub(1, pipeIdx - 1)
          local ts = line:sub(pipeIdx + 1)
          local name = path:match("([^/]+)$") or path
          table.insert(list, { path = path, name = name, timestamp = ts })
        end
      end
    end
    callback(list)
  end)
end

local function listFolder(dir, callback)
  local cmd = `ls -Ap '{dir}' 2>/dev/null | grep '/$'`
  noctalia.runAsync(cmd, function(res)
    local list = {}
    if res.exitCode == 0 then
      for line in (res.stdout or res.body or ""):gmatch("[^\r\n]+") do
        local folder = line:gsub("/", "")
        table.insert(list, folder)
      end
    end
    callback(list)
  end)
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

function onQuery(query)
  local filter = query:gsub("^%s+", ""):gsub("%s+$", "")

  checkZedInstalled(function()
    if not zedInstalled then
      launcher.setResults(query, {
        {
          id = "error_not_installed",
          title = tr("launcher.not_installed"),
          subtitle = tr("launcher.not_installed_desc"),
          glyph = "alert-circle"
        }
      })
      return
    end

    if filter:find("^/") or filter:find("^~") then
      -- Directory Browsing Mode
      local resolvedQuery = filter:gsub("^~", home)
      local hasTrailingSlash = resolvedQuery:find("/$") ~= nil

      if hasTrailingSlash then
        listFolder(resolvedQuery, function(folders)
          local results = {}
          
          -- Open Current Folder Action
          local currentFolder = resolvedQuery:match("([^/]+)/$") or resolvedQuery
          table.insert(results, {
            id = `open:{resolvedQuery}`,
            title = tr("launcher.open_folder", { path = currentFolder }),
            subtitle = resolvedQuery,
            glyph = "folder-plus"
          })

          for _, f in folders do
            local fullPath = resolvedQuery .. f
            table.insert(results, {
              id = `dir:{fullPath}/`,
              title = f,
              subtitle = fullPath,
              glyph = "folder"
            })
          end
          launcher.setResults(query, results)
        end)
      else
        local lastSlashIndex = 1
        for i = #resolvedQuery, 1, -1 do
          if resolvedQuery:sub(i,i) == "/" then
            lastSlashIndex = i
            break
          end
        end
        local searchBase = resolvedQuery:sub(1, lastSlashIndex)
        local searchTerm = resolvedQuery:sub(lastSlashIndex + 1):lower()

        listFolder(searchBase, function(folders)
          local results = {}
          
          if searchTerm ~= "" then
            table.insert(results, {
              id = `dir:{resolvedQuery}/`,
              title = tr("launcher.search_folder", { path = resolvedQuery }),
              subtitle = searchBase,
              glyph = "search"
            })
          end

          for _, f in folders do
            if f:lower():find(searchTerm, 1, true) then
              local fullPath = searchBase .. f
              table.insert(results, {
                id = `dir:{fullPath}/`,
                title = f,
                subtitle = fullPath,
                glyph = "folder"
              })
            end
          end
          launcher.setResults(query, results)
        end)
      end
    else
      -- Recent Projects Mode
      getRecentProjects(function(projects)
        loadState(function()
          local filtered = {}
          local q = filter:lower()
          for _, p in projects do
            if q == "" or p.name:lower():find(q, 1, true) or p.path:lower():find(q, 1, true) then
              table.insert(filtered, p)
            end
          end

          if #filtered == 0 then
            launcher.setResults(query, {})
            return
          end

          -- Sort the rest by openCounts frequency
          if #filtered > 1 then
            local first = filtered[1]
            local rest = {}
            for i = 2, #filtered do
              table.insert(rest, filtered[i])
            end
            table.sort(rest, function(a, b)
              local countA = openCounts[a.path] or 0
              local countB = openCounts[b.path] or 0
              return countA > countB
            end)
            filtered = { first }
            for _, r in rest do
              table.insert(filtered, r)
            end
          end

          local results = {}
          for _, p in filtered do
            table.insert(results, {
              id = `proj:{p.path}`,
              title = p.name,
              subtitle = p.path,
              glyph = "code"
            })
          end
          launcher.setResults(query, results)
        end)
      end)
    end
  end)
end

function onActivate(id)
  if id:find("open:", 1, true) == 1 then
    local path = id:match("^open:(.*)$")
    if path then
      local escaped = path:gsub("'", "'\\''")
      noctalia.runAsync(`bash -l -c "{zedBin} '{escaped}'"`)
    end
  elseif id:find("dir:", 1, true) == 1 then
    local path = id:match("^dir:(.*)$")
    if path then
      -- Pre-fill search with the selected directory path
      launcher.setSearchText(`>zed {path}`)
    end
  elseif id:find("proj:", 1, true) == 1 then
    local path = id:match("^proj:(.*)$")
    if path then
      openCounts[path] = (openCounts[path] or 0) + 1
      saveState()
      local escaped = path:gsub("'", "'\\''")
      noctalia.runAsync(`bash -l -c "{zedBin} '{escaped}'"`)
    end
  end
end
