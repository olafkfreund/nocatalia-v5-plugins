-- Launcher Pass — launcher provider.
-- Search gnu pass password entries from the launcher.

local currentPath = ""
local entryStack = {}
local isDetailMode = false
local selectedEntry = nil
local cachedEntries = {}
local loaded = false
local searchQuery = ""
local lastQueryTime = 0

local storePathSetting = launcher.getConfig("storePath") or ""
local passwordStoreDir
if storePathSetting ~= "" then
  passwordStoreDir = noctalia.expandPath(storePathSetting)
else
  passwordStoreDir = (os.getenv("HOME") or "/tmp") .. "/.password-store"
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shellEscape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
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

local function resolveDir()
  if currentPath == "" then
    return passwordStoreDir
  else
    return passwordStoreDir .. "/" .. currentPath
  end
end

local function getClipTimeout()
  local configured = launcher.getConfig("clipTimeout") or ""
  if configured ~= "" then
    local num = tonumber(configured)
    if num and num > 0 then return num end
  end
  local envValue = os.getenv("PASSWORD_STORE_CLIP_TIME") or ""
  if envValue ~= "" then
    local num = tonumber(envValue)
    if num and num > 0 then return num end
  end
  return nil
end

local function getPassEnvPrefix()
  local prefix = "PASSWORD_STORE_DIR=" .. shellEscape(passwordStoreDir)
  local timeout = getClipTimeout()
  if timeout then
    prefix = prefix .. " PASSWORD_STORE_CLIP_TIME=" .. tostring(timeout)
  end
  return prefix
end

local function parseEntries(text, isSearch)
  local entries = {}
  local seenDirs = {}
  
  for line in text:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" then
      local isDir = line:sub(-1) == "/"
      local name = isDir and line:sub(1, -2) or line
      
      if not isDir and name:sub(-4) == ".gpg" then
        name = name:sub(1, -5)
      end
      
      local fullPath
      if currentPath == "" then
        fullPath = name
      else
        fullPath = currentPath .. "/" .. name
      end
      
      if isSearch then
        local lastSlash = name:match("^.*/Impl/()") or name:match("^.*/()")
        if lastSlash then
          local dirPath = name:sub(1, lastSlash - 2)
          if not seenDirs[dirPath] then
            seenDirs[dirPath] = true
            local fullDirPath
            if currentPath == "" then
              fullDirPath = dirPath
            else
              fullDirPath = currentPath .. "/" .. dirPath
            end
            table.insert(entries, {
              name = dirPath,
              fullPath = fullDirPath,
              isDir = true,
              isPassword = false
            })
          end
        end
      end
      
      table.insert(entries, {
        name = name,
        fullPath = fullPath,
        isDir = isDir,
        isPassword = not isDir
      })
    end
  end
  
  table.sort(entries, function(a, b)
    return a.name < b.name
  end)
  
  cachedEntries = entries
end

local function performSearch(queryText, callback)
  local targetDir = resolveDir()
  local cmd
  local isSearch = queryText ~= ""
  if isSearch then
    cmd = "find " .. shellEscape(targetDir) .. " -mindepth 1 -type f -name '*.gpg' -printf '%P\n'"
  else
    cmd = "find " .. shellEscape(targetDir) .. " -maxdepth 1 -mindepth 1 -type f -name '*.gpg' -printf '%f\n' -o -type d -not -name '.*' -printf '%f/\n'"
  end

  loaded = false
  noctalia.runAsync(cmd, function(res)
    loaded = true
    if res.exitCode == 0 then
      local stdout = res.stdout or res.body or ""
      parseEntries(stdout, isSearch)
    else
      cachedEntries = {}
    end
    if callback then callback() end
  end)
end

local function parsePassEntry(output)
  local data = { password = "", fields = {}, hasOtp = false }
  local passwordFound = false
  for line in output:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" then
      if not passwordFound then
        data.password = line
        passwordFound = true
      else
        if line:find("otpauth://", 1, true) then
          data.hasOtp = true
        end
        local colonIndex = line:find(": ", 1, true)
        if colonIndex and colonIndex > 1 then
          local key = line:sub(1, colonIndex - 1)
          local value = line:sub(colonIndex + 2)
          table.insert(data.fields, { key = key, value = value })
        end
      end
    end
  end
  return data
end

local function showPasswordOptions(path)
  selectedEntry = { path = path, data = nil }
  isDetailMode = true
  launcher.setSearchText(">pass ")
  
  local cmd = "PASSWORD_STORE_DIR=" .. shellEscape(passwordStoreDir) .. " pass show " .. shellEscape(path)
  noctalia.runAsync(cmd, function(res)
    if isDetailMode and selectedEntry and selectedEntry.path == path then
      if res.exitCode == 0 then
        local stdout = res.stdout or res.body or ""
        selectedEntry.data = parsePassEntry(stdout)
      else
        isDetailMode = false
        selectedEntry = nil
        launcher.notify("Pass", "Failed to decrypt password entry")
      end
      onQuery(launcher.getQuery())
    end
  end)
end

local function resetDetailMode()
  isDetailMode = false
  selectedEntry = nil
end

local function copyField(path, field)
  resetDetailMode()
  launcher.close()
  local cmd
  if not field then
    cmd = getPassEnvPrefix() .. " pass -c " .. shellEscape(path)
  else
    cmd = "printf '%s' " .. shellEscape(field.value) .. " | wl-copy"
  end
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      launcher.notify("Pass", tr("notification.copied"))
    end
  end)
end

local function typeField(path, field)
  local value = ""
  if field then
    value = field.value
  elseif selectedEntry and selectedEntry.data then
    value = selectedEntry.data.password
  end
  resetDetailMode()
  launcher.close()
  local typeDelay = tonumber(launcher.getConfig("typeDelay")) or 500
  local wtypeDelay = tonumber(launcher.getConfig("wtypeDelay")) or 12
  local cmd = "sleep " .. (typeDelay / 1000) .. " && printf '%s' " .. shellEscape(value) .. " | wtype -d " .. wtypeDelay .. " -"
  noctalia.runAsync(cmd)
end

local function copyOtp(path)
  resetDetailMode()
  launcher.close()
  local cmd = getPassEnvPrefix() .. " pass otp -c " .. shellEscape(path)
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      launcher.notify("Pass", tr("notification.copied"))
    end
  end)
end

local function typeOtp(path)
  resetDetailMode()
  launcher.close()
  local cmd = "PASSWORD_STORE_DIR=" .. shellEscape(passwordStoreDir) .. " pass otp " .. shellEscape(path)
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local otp = trim(res.stdout or res.body or "")
      if otp ~= "" then
        local typeDelay = tonumber(launcher.getConfig("typeDelay")) or 500
        local wtypeDelay = tonumber(launcher.getConfig("wtypeDelay")) or 12
        local typeCmd = "sleep " .. (typeDelay / 1000) .. " && printf '%s' " .. shellEscape(otp) .. " | wtype -d " .. wtypeDelay .. " -"
        noctalia.runAsync(typeCmd)
      end
    end
  end)
end

local function goBack()
  if #entryStack == 0 then return end
  local prev = table.remove(entryStack)
  currentPath = prev.path
  searchQuery = prev.query
  local prefix = ">pass"
  if searchQuery ~= "" then
    prefix = ">pass " .. searchQuery
  else
    prefix = ">pass "
  end
  launcher.setSearchText(prefix)
  performSearch(searchQuery)
end

local function navigateToPath(path)
  table.insert(entryStack, { path = currentPath, query = searchQuery })
  currentPath = path
  searchQuery = ""
  isDetailMode = false
  selectedEntry = nil
  launcher.setSearchText(">pass ")
  performSearch("")
end

local function fuzzyMatch(query, target)
  query = query:lower()
  target = target:lower()
  if query == "" then return 1 end

  local parts = {}
  for part in query:gmatch("%S+") do
    table.insert(parts, part)
  end
  if #parts == 0 then return 1 end

  for _, part in ipairs(parts) do
    if not target:find(part, 1, true) then
      return 0
    end
  end

  local score = 1
  if target:find(query, 1, true) == 1 then
    score = score + 1
  end
  return score
end

function onQuery(query)
  local filter = trim(query)
  local isCommandMode = filter:find("^>pass") ~= nil

  local includeInSearch = launcher.getConfig("includeInSearch") ~= false
  if not isCommandMode and not includeInSearch then
    launcher.setResults(query, {})
    return
  end

  local searchWord = filter
  if isCommandMode then
    searchWord = filter:gsub("^>pass%s*", "")
  end
  searchWord = trim(searchWord)

  -- Inactivity reset logic
  local now = os.time()
  if now - lastQueryTime > 10 and (query == ">pass" or query == ">pass ") then
    currentPath = ""
    entryStack = {}
    isDetailMode = false
    selectedEntry = nil
  end
  lastQueryTime = now

  -- If in detail mode
  if isDetailMode and selectedEntry then
    local results = {}
    table.insert(results, {
      id = "goback",
      title = tr("result.goBack"),
      subtitle = selectedEntry.path,
      glyph = "arrow-left"
    })

    if not selectedEntry.data then
      table.insert(results, {
        id = "loading",
        title = tr("result.loading"),
        glyph = "refresh",
        badgeIcon = "loader"
      })
      launcher.setResults(query, results)
      return
    end

    local data = selectedEntry.data
    local path = selectedEntry.path

    table.insert(results, {
      id = "copy_pass:" .. path,
      title = tr("action.copyPassword"),
      subtitle = tr("action.copyPasswordDesc"),
      glyph = "copy"
    })

    table.insert(results, {
      id = "type_pass:" .. path,
      title = tr("action.typePassword"),
      subtitle = tr("action.typePasswordDesc"),
      glyph = "typography"
    })

    if data.hasOtp then
      table.insert(results, {
        id = "copy_otp:" .. path,
        title = tr("action.copyOtp"),
        subtitle = tr("action.otpDesc"),
        glyph = "copy"
      })

      table.insert(results, {
        id = "type_otp:" .. path,
        title = tr("action.typeOtp"),
        subtitle = tr("action.otpDesc"),
        glyph = "typography"
      })
    end

    for _, f in ipairs(data.fields) do
      table.insert(results, {
        id = "copy_field:" .. path .. "|" .. f.key .. "|" .. f.value,
        title = tr("action.copyField", { key = f.key }),
        subtitle = f.value,
        glyph = "copy"
      })
      table.insert(results, {
        id = "type_field:" .. path .. "|" .. f.key .. "|" .. f.value,
        title = tr("action.typeField", { key = f.key }),
        subtitle = f.value,
        glyph = "typography"
      })
    end

    launcher.setResults(query, results)
    return
  end

  -- If searchQuery has changed
  if searchWord ~= searchQuery then
    searchQuery = searchWord
    performSearch(searchQuery, function()
      onQuery(launcher.getQuery())
    end)
  end

  local results = {}
  if currentPath ~= "" then
    table.insert(results, {
      id = "goback",
      title = tr("result.goBack"),
      subtitle = currentPath,
      glyph = "arrow-left"
    })
  end

  local scored = {}
  for _, entry in ipairs(cachedEntries) do
    local score = fuzzyMatch(searchQuery, entry.name)
    if score > 0 then
      table.insert(scored, { entry = entry, score = score })
    end
  end

  table.sort(scored, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.entry.name < b.entry.name
  end)

  local limit = math.min(#scored, 50)
  for i = 1, limit do
    local entry = scored[i].entry
    local descKey = "result.password"
    if entry.isDir then
      descKey = "result.folder"
    end
    local glyph = "key"
    if entry.isDir then
      glyph = "folder"
    end
    local idPrefix = "pass:"
    if entry.isDir then
      idPrefix = "dir:"
    end
    table.insert(results, {
      id = idPrefix .. entry.fullPath,
      title = entry.name,
      subtitle = tr(descKey),
      glyph = glyph
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id == "goback" then
    if isDetailMode then
      resetDetailMode()
      launcher.setSearchText(">pass ")
      onQuery(launcher.getQuery())
    else
      goBack()
    end
  elseif id:sub(1, 4) == "dir:" then
    local path = id:sub(5)
    navigateToPath(path)
  elseif id:sub(1, 5) == "pass:" then
    local path = id:sub(6)
    showPasswordOptions(path)
  elseif id:sub(1, 10) == "copy_pass:" then
    local path = id:sub(11)
    copyField(path, nil)
  elseif id:sub(1, 10) == "type_pass:" then
    local path = id:sub(11)
    typeField(path, nil)
  elseif id:sub(1, 9) == "copy_otp:" then
    local path = id:sub(10)
    copyOtp(path)
  elseif id:sub(1, 9) == "type_otp:" then
    local path = id:sub(10)
    typeOtp(path)
  elseif id:sub(1, 11) == "copy_field:" then
    local payload = id:sub(12)
    local path, key, value = payload:match("^([^|]+)|([^|]+)|(.*)$")
    if path and key and value then
      copyField(path, { key = key, value = value })
    end
  elseif id:sub(1, 11) == "type_field:" then
    local payload = id:sub(12)
    local path, key, value = payload:match("^([^|]+)|([^|]+)|(.*)$")
    if path and key and value then
      typeField(path, { key = key, value = value })
    end
  end
end
