-- Calibre Provider — launcher provider.
-- Searches books in the Calibre library and opens them.

local database = {}
local loaded = false
local loading = false
local recentlyOpened = {}

local function getScriptPaths()
  local home = os.getenv("HOME") or "/tmp"
  return {
    "calibre-provider/load_calibre_db.py",
    `{home}/.local/share/noctalia/plugins/calibre-provider/load_calibre_db.py`,
    `{home}/.local/share/noctalia/plugins/calibre-provider-master/load_calibre_db.py`
  }
end

local function loadDb(onDone)
  if loading then return end
  loading = true
  
  local testPaths = getScriptPaths()
  
  local function tryPath(index)
    if index > #testPaths then
      noctalia.log("Calibre Provider: load_calibre_db.py not found in any tested path")
      loading = false
      if onDone then onDone(false) end
      return
    end
    
    local path = testPaths[index]
    noctalia.runAsync(`test -f '{path}'`, function(checkRes)
      if checkRes.exitCode == 0 then
        noctalia.runAsync(`python3 '{path}'`, function(res)
          if res.exitCode == 0 then
            local success, parsed = pcall(noctalia.json.decode, res.stdout or res.body)
            if success and type(parsed) == "table" then
              database = {}
              for _, entry in parsed do
                if entry.id then
                  database[tostring(entry.id)] = entry
                end
              end
              loaded = true
              loading = false
              noctalia.log(`Calibre Provider: loaded {#parsed} books from database`)
              if onDone then onDone(true) end
            else
              noctalia.log("Calibre Provider: failed to parse database output")
              loading = false
              if onDone then onDone(false) end
            end
          else
            noctalia.log(`Calibre Provider: script exited with code {res.exitCode}`)
            loading = false
            if onDone then onDone(false) end
          end
        end)
      else
        tryPath(index + 1)
      end
    end)
  end
  
  tryPath(1)
end

-- Initialize database load
loadDb()

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  if not loaded then
    if loading then
      table.insert(results, {
        id = "loading",
        title = "Loading database...",
        subtitle = "Reading Calibre library...",
        glyph = "loader",
      })
    else
      table.insert(results, {
        id = "not_loaded",
        title = "Database not loaded",
        subtitle = "Click or press Enter to load",
        glyph = "alert-circle",
      })
    end
    launcher.setResults(query, results)
    return
  end

  if filter == "" then
    local limit = launcher.getConfig("recentlyOpenedMax") or 36
    local count = 0
    for _, id in recentlyOpened do
      local book = database[tostring(id)]
      if book and count < limit then
        table.insert(results, {
          id = tostring(book.id),
          title = book.title or "Unknown",
          subtitle = book.authors or "Unknown Author",
          glyph = "book",
        })
        count += 1
      end
    end
    if #results == 0 then
      table.insert(results, {
        id = "empty_history",
        title = "Calibre Search",
        subtitle = "Type to search books in your library",
        glyph = "books",
      })
    end
    launcher.setResults(query, results)
    return
  end

  local matches = 0
  for id, book in database do
    local title = (book.title or ""):lower()
    local authors = (book.authors or ""):lower()
    if title:find(filter, 1, true) or authors:find(filter, 1, true) then
      table.insert(results, {
        id = tostring(book.id),
        title = book.title or "Unknown",
        subtitle = book.authors or "Unknown Author",
        glyph = "book",
      })
      matches += 1
      if matches >= 50 then break end
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "no_results",
      title = "No books found",
      subtitle = "Try a different search query",
      glyph = "alert-circle",
    })
  end

  launcher.setResults(query, results)
end

local function updateRecentlyOpened(id)
  local newMru = { id }
  local max = launcher.getConfig("recentlyOpenedMax") or 36
  for _, existingId in recentlyOpened do
    if existingId ~= id and #newMru < max then
      table.insert(newMru, existingId)
    end
  end
  recentlyOpened = newMru
end

function onActivate(id)
  if id == "not_loaded" then
    loadDb(function(success)
      if success then
        launcher.notify("Calibre", "Database loaded successfully!")
      else
        launcher.notify("Calibre", "Failed to load database.")
      end
    end)
    return
  end

  if id == "loading" or id == "no_results" or id == "empty_history" then
    return
  end

  local book = database[id]
  if book and book.file then
    updateRecentlyOpened(id)
    local openCmd = launcher.getConfig("launcher") or "xdg-open"
    noctalia.runAsync(`{openCmd} '{book.file}'`)
  end
end
