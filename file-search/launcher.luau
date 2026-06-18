-- File Search — launcher provider.

local function tr(key, replacements)
  local val = noctalia.tr(key) or key
  if replacements then
    for k, v in pairs(replacements) do
      val = val:gsub("{{" .. k .. "}}", tostring(v))
    end
  end
  return val
end

local function escapeShellArg(arg)
  return "'" .. string.gsub(arg, "'", "'\\''") .. "'"
end

local function expandHomePath(path)
  if path:sub(1, 1) == "~" then
    local home = os.getenv("HOME") or ""
    return home .. path:sub(2)
  end
  return path
end

local function displaySearchDirectory(searchDir)
  local expandedPath = expandHomePath(searchDir)
  local homeDir = os.getenv("HOME") or ""
  if homeDir ~= "" and expandedPath:sub(1, #homeDir) == homeDir then
    return "~" .. expandedPath:sub(#homeDir + 1)
  end
  return expandedPath
end

local function getFileIcon(filename)
  local parts = {}
  for part in filename:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  local ext = ""
  if #parts > 1 then
    ext = parts[#parts]:lower()
  end
  
  -- Images
  if ext == "jpg" or ext == "jpeg" or ext == "png" or ext == "gif" or ext == "svg" or ext == "webp" or ext == "bmp" or ext == "ico" then
    return "photo"
  end
  
  -- Documents
  if ext == "txt" or ext == "md" or ext == "pdf" or ext == "doc" or ext == "docx" or ext == "odt" or ext == "rtf" then
    return "file-text"
  end
  
  -- Code files
  if ext == "js" or ext == "ts" or ext == "py" or ext == "java" or ext == "cpp" or ext == "c" or ext == "h" or ext == "qml" or ext == "rs" or ext == "go" or ext == "rb" or ext == "php" or ext == "html" or ext == "css" or ext == "json" or ext == "xml" or ext == "yaml" or ext == "yml" or ext == "luau" or ext == "lua" then
    return "code"
  end
  
  -- Archives
  if ext == "zip" or ext == "tar" or ext == "gz" or ext == "bz2" or ext == "xz" or ext == "7z" or ext == "rar" then
    return "file-zip"
  end
  
  -- Audio
  if ext == "mp3" or ext == "wav" or ext == "flac" or ext == "ogg" or ext == "m4a" or ext == "aac" or ext == "wma" then
    return "music"
  end
  
  -- Video
  if ext == "mp4" or ext == "mkv" or ext == "avi" or ext == "mov" or ext == "wmv" or ext == "flv" or ext == "webm" then
    return "video"
  end
  
  -- Spreadsheets
  if ext == "xls" or ext == "xlsx" or ext == "ods" or ext == "csv" then
    return "table"
  end
  
  -- Presentations
  if ext == "ppt" or ext == "pptx" or ext == "odp" then
    return "presentation"
  end
  
  -- Default
  return "file"
end

local function formatFileEntry(filePath, forcedIsDirectory)
  local normalizedPath = filePath
  while #normalizedPath > 1 and normalizedPath:sub(-1) == "/" do
    normalizedPath = normalizedPath:sub(1, -2)
  end

  local isDirectory = false
  if forcedIsDirectory ~= nil then
    isDirectory = forcedIsDirectory
  else
    isDirectory = normalizedPath ~= filePath
  end

  local parts = {}
  for part in normalizedPath:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  local filename = parts[#parts] or normalizedPath
  
  local parentPath = ""
  if #parts > 1 then
    local parentParts = {}
    for i = 1, #parts - 1 do
      table.insert(parentParts, parts[i])
    end
    if filePath:sub(1, 1) == "/" then
      parentPath = "/" .. table.concat(parentParts, "/")
    else
      parentPath = table.concat(parentParts, "/")
    end
  else
    if filePath:sub(1, 1) == "/" then
      parentPath = "/"
    else
      parentPath = ""
    end
  end

  local homeDir = os.getenv("HOME") or ""
  if homeDir ~= "" and parentPath:sub(1, #homeDir) == homeDir then
    parentPath = "~" .. parentPath:sub(#homeDir + 1)
  end

  return {
    id = normalizedPath,
    title = filename,
    subtitle = parentPath,
    glyph = isDirectory and "folder" or getFileIcon(filename)
  }
end

local function resultRank(result, queryLower)
  local name = (result.title or ""):lower()
  local description = (result.subtitle or ""):lower()
  local fullPath = description .. "/" .. name

  if name == queryLower then
    return 0
  end
  if name:sub(1, #queryLower) == queryLower then
    return 1
  end
  if name:find(queryLower, 1, true) then
    return 2
  end
  if fullPath:find(queryLower, 1, true) then
    return 3
  end
  return 4
end

local function sortResults(results, query)
  local queryLower = query:lower()
  table.sort(results, function(a, b)
    local rankA = resultRank(a, queryLower)
    local rankB = resultRank(b, queryLower)
    if rankA ~= rankB then
      return rankA < rankB
    end

    local nameA = (a.title or ""):lower()
    local nameB = (b.title or ""):lower()
    if nameA ~= nameB then
      return nameA < nameB
    end

    return #(a.subtitle or "") < #(b.subtitle or "")
  end)
  return results
end

local activeRequestId = 0

function onQuery(query)
  local filter = query:gsub("^%s+", ""):gsub("%s+$", "")
  
  local showHidden = launcher.getConfig("showHidden") == true
  local maxResults = tonumber(launcher.getConfig("maxResults")) or 100
  local fdCommand = launcher.getConfig("fdCommand") or "fd"
  local searchDirectory = launcher.getConfig("searchDirectory") or "~"
  
  if filter == "" then
    launcher.setResults(query, {
      {
        id = "empty_query",
        title = tr("launcher.prompts.emptyQuery.title"),
        subtitle = tr("launcher.prompts.emptyQuery.description", { root = displaySearchDirectory(searchDirectory) }),
        glyph = "file-search"
      }
    })
    return
  end
  
  activeRequestId = activeRequestId + 1
  local requestId = activeRequestId
  
  launcher.setResults(query, {
    {
      id = "searching",
      title = tr("launcher.prompts.searching.title"),
      subtitle = tr("launcher.prompts.searching.description", { query = filter }),
      glyph = "refresh"
    }
  })
  
  local expandedDir = expandHomePath(searchDirectory)
  
  local commonArgs = { "--color", "never", "--absolute-path" }
  if showHidden then
    table.insert(commonArgs, "--hidden")
  end
  if maxResults > 0 then
    table.insert(commonArgs, "--max-results")
    table.insert(commonArgs, tostring(maxResults))
  end
  table.insert(commonArgs, "--base-directory")
  table.insert(commonArgs, expandedDir)
  
  local commonArgsEscaped = {}
  for _, arg in ipairs(commonArgs) do
    table.insert(commonArgsEscaped, escapeShellArg(arg))
  end
  local commonArgsStr = table.concat(commonArgsEscaped, " ")
  
  local queryEscaped = escapeShellArg(filter)
  local fdCommandEscaped = escapeShellArg(fdCommand)
  
  local fullCommand = string.format(
    "%s --type d %s %s ; echo '__DIR_FILE_SEP__' ; %s --type f %s %s",
    fdCommandEscaped, commonArgsStr, queryEscaped,
    fdCommandEscaped, commonArgsStr, queryEscaped
  )
  
  noctalia.runAsync(fullCommand, function(res)
    if requestId ~= activeRequestId then
      return
    end
    
    if res.exitCode ~= 0 then
      launcher.setResults(query, {
        {
          id = "error",
          title = tr("launcher.errors.fdNotFound.title"),
          subtitle = tr("launcher.errors.fdNotFound.description"),
          glyph = "alert-circle"
        }
      })
      return
    end
    
    local stdout = res.stdout or ""
    local isDir = true
    local dirs = {}
    local files = {}
    
    for line in stdout:gmatch("[^\r\n]+") do
      local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
      if trimmed ~= "" then
        if trimmed == "__DIR_FILE_SEP__" then
          isDir = false
        else
          if isDir then
            table.insert(dirs, trimmed)
          else
            table.insert(files, trimmed)
          end
        end
      end
    end
    
    local formattedResults = {}
    for _, path in ipairs(dirs) do
      table.insert(formattedResults, formatFileEntry(path, true))
    end
    for _, path in ipairs(files) do
      table.insert(formattedResults, formatFileEntry(path, false))
    end
    
    formattedResults = sortResults(formattedResults, filter)
    
    if maxResults > 0 and #formattedResults > maxResults then
      local limited = {}
      for i = 1, maxResults do
        table.insert(limited, formattedResults[i])
      end
      formattedResults = limited
    end
    
    if #formattedResults == 0 then
      launcher.setResults(query, {
        {
          id = "no_results",
          title = tr("launcher.prompts.noResults.title"),
          subtitle = tr("launcher.prompts.noResults.description", { query = filter }),
          glyph = "file-off"
        }
      })
    else
      launcher.setResults(query, formattedResults)
    end
  end)
end

function onActivate(id)
  if id == "empty_query" or id == "searching" or id == "error" or id == "no_results" then
    return
  end
  
  local fileOpener = launcher.getConfig("fileOpener") or "xdg-open"
  noctalia.runAsync(string.format("%s %s", escapeShellArg(fileOpener), escapeShellArg(id)))
  launcher.close()
end
