-- Kaomoji Provider — launcher provider.
-- Browse and search kaomoji emoticons and copy them to clipboard.

local database = {}
local keys = {}
local loaded = false
local loading = false

local function getDatabasePaths()
  local home = os.getenv("HOME") or "/tmp"
  return {
    "kaomoji-provider/database.json",
    `{home}/.local/share/noctalia/plugins/kaomoji-provider/database.json`,
    `{home}/.local/share/noctalia/plugins/kaomoji-provider-master/database.json`
  }
end

local function loadDb()
  if loading or loaded then return end
  loading = true

  local paths = getDatabasePaths()
  local function tryPath(index)
    if index > #paths then
      noctalia.log("Kaomoji Provider: database.json not found in any tested path")
      loading = false
      return
    end

    local path = paths[index]
    noctalia.runAsync(`test -f '{path}'`, function(checkRes)
      if checkRes.exitCode == 0 then
        noctalia.log(`Kaomoji Provider: Loading database from {path}`)
        noctalia.runAsync(`cat '{path}'`, function(res)
          if res.exitCode == 0 then
            local success, parsed = pcall(noctalia.json.decode, res.stdout or res.body)
            if success and type(parsed) == "table" then
              database = parsed
              keys = {}
              for k, _ in database do
                table.insert(keys, k)
              end
              table.sort(keys)
              loaded = true
              loading = false
              noctalia.log(`Kaomoji Provider: Loaded {#keys} kaomojis`)
            else
              noctalia.log("Kaomoji Provider: Failed to decode database.json")
              loading = false
            end
          else
            noctalia.log(`Kaomoji Provider: cat exited with code {res.exitCode}`)
            loading = false
          end
        end)
      else
        tryPath(index + 1)
      end
    end)
  end

  tryPath(1)
end

loadDb()

local categories = {"all", "smiling", "heart", "blush", "kiss", "bear", "cat", "sad", "crying", "anger", "music", "hug", "surprised"}
local categoryNames = {
  all = "All",
  smiling = "Happy",
  heart = "Love",
  blush = "Blush",
  kiss = "Kiss",
  bear = "Bear",
  cat = "Cat",
  sad = "Sad",
  crying = "Crying",
  anger = "Angry",
  music = "Music",
  hug = "Hug",
  surprised = "Surprised"
}
local categoryIcons = {
  all = "list",
  smiling = "mood-smile",
  heart = "heart",
  blush = "mood-heart",
  kiss = "mood-tongue",
  bear = "paw",
  cat = "cat",
  sad = "mood-sad",
  crying = "mood-cry",
  anger = "mood-angry",
  music = "music",
  hug = "friends",
  surprised = "mood-surprised"
}

local selectedCategory = "all"

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  if not loaded then
    if loading then
      table.insert(results, {
        id = "loading",
        title = "Loading database...",
        subtitle = "Reading kaomoji database...",
        glyph = "loader"
      })
    else
      table.insert(results, {
        id = "not_loaded",
        title = "Database not loaded",
        subtitle = "Press Enter to load kaomoji database",
        glyph = "alert-circle"
      })
    end
    launcher.setResults(query, results)
    return
  end

  if filter == "" then
    -- Browse Mode
    for _, cat in categories do
      local isSelected = cat == selectedCategory
      local titlePrefix = if isSelected then "● " else "  "
      table.insert(results, {
        id = `cat:{cat}`,
        title = `{titlePrefix}{categoryNames[cat] or cat}`,
        subtitle = `Browse {cat} kaomojis`,
        glyph = categoryIcons[cat] or "category"
      })
    end

    local count = 0
    for _, k in keys do
      if count >= 100 then break end
      local entry = database[k]
      local show = false
      if selectedCategory == "all" then
        show = true
      else
        local tags = entry.new_tags or {}
        for _, tag in tags do
          if tag == selectedCategory then
            show = true
            break
          end
        end
        if not show then
          local otags = entry.original_tags or {}
          for _, tag in otags do
            if tag == selectedCategory then
              show = true
              break
            end
          end
        end
      end

      if show then
        local desc = ""
        if entry.new_tags and #entry.new_tags > 0 then
          desc = table.concat(entry.new_tags, ", ")
        end
        table.insert(results, {
          id = `kao:{k}`,
          title = k,
          subtitle = desc,
          glyph = "mood-wink"
        })
        count += 1
      end
    end
  else
    -- Search Mode
    local count = 0
    for _, k in keys do
      if count >= 50 then break end
      local entry = database[k]
      local match = false
      
      if k:lower():find(filter, 1, true) then
        match = true
      else
        local tags = entry.new_tags or {}
        for _, tag in tags do
          if tag:lower():find(filter, 1, true) then
            match = true
            break
          end
        end
        if not match then
          local otags = entry.original_tags or {}
          for _, tag in otags do
            if tag:lower():find(filter, 1, true) then
              match = true
              break
            end
          end
        end
      end

      if match then
        local desc = ""
        if entry.new_tags and #entry.new_tags > 0 then
          desc = table.concat(entry.new_tags, ", ")
        end
        table.insert(results, {
          id = `kao:{k}`,
          title = k,
          subtitle = desc,
          glyph = "mood-wink"
        })
        count += 1
      end
    end

    if #results == 0 then
      table.insert(results, {
        id = "no_results",
        title = "No kaomojis found",
        subtitle = "Try a different query",
        glyph = "alert-circle"
      })
    end
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id == "not_loaded" then
    loadDb()
    return
  elseif id == "loading" or id == "no_results" then
    return
  elseif id:find("cat:", 1, true) == 1 then
    local cat = id:match("^cat:(.*)$")
    if cat then
      selectedCategory = cat
      onQuery("")
    end
    return
  elseif id:find("kao:", 1, true) == 1 then
    local kao = id:match("^kao:(.*)$")
    if kao then
      local escaped = kao:gsub("'", "'\\''")
      noctalia.runAsync(`printf '%s' '{escaped}' | wl-copy`)
      launcher.notify("Kaomoji", `Copied to clipboard: {kao}`)
    end
  end
end
