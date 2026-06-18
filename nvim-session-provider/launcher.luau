-- Neovim Session Provider — launcher provider.
-- Searches and opens Neovim sessions.

local database = {}
local loaded = false
local loading = false

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

local function split(str, sep)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(str, sep, from, true)
  while delim_from do
    table.insert(result, string.sub(str, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(str, sep, from, true)
  end
  table.insert(result, string.sub(str, from))
  return result
end

local function simplifyFilename(fullname)
  local pathSep = nil
  local branchSep = nil
  local stripSuffix = false

  if fullname:sub(1, 2) == "__" then
    pathSep = "__"
  elseif fullname:sub(1, 3) == "%2F" then
    pathSep = "%2F"
    branchSep = "%7C"
    stripSuffix = true
  elseif fullname:sub(1, 1) == "%" then
    pathSep = "%"
    branchSep = "%%"
    stripSuffix = true
  end

  if stripSuffix then
    fullname = fullname:gsub("%.vim$", "")
  end

  local branchName = nil
  if branchSep then
    local parts = split(fullname, branchSep)
    if #parts > 1 then
      branchName = table.remove(parts)
      fullname = table.concat(parts, branchSep)
    end
  end

  local dirname = fullname
  if pathSep then
    local parts = split(fullname, pathSep)
    if #parts > 0 then
      dirname = parts[#parts]
    end
  end

  if branchName then
    return dirname .. " (" .. branchName .. ")"
  else
    return dirname
  end
end

local function getWorkspacePath(sessionText)
  for line in sessionText:gmatch("[^\r\n]+") do
    if line:sub(1, 3) == "cd " then
      return line:sub(4)
    end
  end
  return nil
end

local function loadSessions(query)
  if loading then return end
  loading = true
  loaded = false

  local sessionDirSetting = launcher.getConfig("sessionDir") or "~/.local/share/nvim/sessions"
  local sessionDir = noctalia.expandPath(sessionDirSetting)

  -- Run ls -1t to get the session files in order of modification time
  noctalia.runAsync("ls -1t '" .. sessionDir:gsub("'", "'\\''") .. "' 2>/dev/null", function(res)
    local list = {}
    if res.exitCode == 0 then
      local stdout = res.stdout or res.body or ""
      for filename in stdout:gmatch("[^\r\n]+") do
        local trimmed = trim(filename)
        if trimmed ~= "" then
          local fullPath = sessionDir .. "/" .. trimmed
          local displayName = simplifyFilename(trimmed)
          local content = noctalia.readFile(fullPath)
          local workspacePath = ""
          if content then
            workspacePath = getWorkspacePath(content) or ""
          end
          table.insert(list, {
            fullPath = fullPath,
            displayName = displayName,
            workspacePath = workspacePath
          })
        end
      end
    end

    database = list
    loaded = true
    loading = false

    -- Refresh results
    onQuery(query)
  end)
end

function onQuery(query)
  local filter = trim(query)
  local isCommandMode = filter:find("^>nvim") ~= nil

  local includeInSearch = launcher.getConfig("includeInSearch") ~= false
  if not isCommandMode and not includeInSearch then
    launcher.setResults(query, {})
    return
  end

  if not loaded then
    loadSessions(query)
    launcher.setResults(query, {
      {
        id = "loading",
        title = tr("launcher.loading.title"),
        subtitle = tr("launcher.loading.description"),
        glyph = "loader"
      }
    })
    return
  end

  local searchWord = filter
  if isCommandMode then
    searchWord = filter:gsub("^>nvim%s*", "")
  end
  searchWord = trim(searchWord):lower()

  local results = {}
  for _, entry in ipairs(database) do
    if searchWord == "" or entry.displayName:lower():find(searchWord, 1, true) or entry.workspacePath:lower():find(searchWord, 1, true) then
      table.insert(results, {
        id = "session:" .. entry.fullPath,
        title = entry.displayName,
        subtitle = entry.workspacePath,
        glyph = "code",
        badgeIcon = "folder-open"
      })
    end
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id:find("session:", 1, true) == 1 then
    local fullPath = id:match("^session:(.*)$")
    if fullPath then
      local nvim = launcher.getConfig("nvim") or "nvim"
      local runInTerminal = launcher.getConfig("runInTerminal") ~= false
      local escapedPath = fullPath:gsub("'", "'\\''")
      local cmd = nvim .. " -S '" .. escapedPath .. "'"

      if runInTerminal then
        noctalia.runInTerminal(cmd)
      else
        noctalia.runAsync(cmd)
      end
    end
  end
end
