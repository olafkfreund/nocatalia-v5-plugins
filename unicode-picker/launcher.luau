-- Unicode Picker — launcher provider.
-- Browse and search Unicode characters, copy to clipboard, and track recent usage.

local home = os.getenv("HOME") or "/tmp"
local cacheDir = `{home}/.cache/noctalia/plugins/unicode-picker`
local usageFilePath = `{cacheDir}/unicode_usage.json`
local unicodeDataPath = `{cacheDir}/UnicodeData.txt`
local nameAliasesPath = `{cacheDir}/NameAliases.txt`
local unicodeDataUrl = "https://unicode.org/Public/15.1.0/ucd/UnicodeData.txt"
local nameAliasesUrl = "https://unicode.org/Public/15.1.0/ucd/NameAliases.txt"

local usageCounts = {}
local unicodeNames = {}
local loaded = false
local loading = false
local namesLoaded = false

local selectedCategory = "recent"

local unicodeBlocks = {
  { name = "arrows", start = 0x2190, ["end"] = 0x21FF, icon = "arrows-left-right" },
  { name = "mathematical", start = 0x2200, ["end"] = 0x22FF, icon = "math-function" },
  { name = "box-drawing", start = 0x2500, ["end"] = 0x257F, icon = "layout-board" },
  { name = "block-elements", start = 0x2580, ["end"] = 0x259F, icon = "square-filled" },
  { name = "geometric", start = 0x25A0, ["end"] = 0x25FF, icon = "shapes" },
  { name = "misc-symbols", start = 0x2600, ["end"] = 0x26FF, icon = "star" },
  { name = "currency", start = 0x20A0, ["end"] = 0x20CF, icon = "currency-dollar" },
  { name = "greek", start = 0x0370, ["end"] = 0x03FF, icon = "omega" },
  { name = "cyrillic", start = 0x0400, ["end"] = 0x04FF, icon = "letter-a" },
  { name = "misc-technical", start = 0x2300, ["end"] = 0x23FF, icon = "tool" },
  { name = "superscripts", start = 0x2070, ["end"] = 0x209F, icon = "superscript" },
  { name = "number-forms", start = 0x2150, ["end"] = 0x218F, icon = "numbers" },
  { name = "dingbats", start = 0x2700, ["end"] = 0x27BF, icon = "scissors" },
  { name = "latin-extended", start = 0x0100, ["end"] = 0x017F, icon = "letter-case" },
  { name = "braille", start = 0x2800, ["end"] = 0x28FF, icon = "dots" }
}

local categories = { "recent" }
for _, b in unicodeBlocks do
  table.insert(categories, b.name)
end

local categoryNames = {
  recent = "Recent",
  arrows = "Arrows",
  mathematical = "Mathematical",
  ["box-drawing"] = "Box Drawing",
  ["block-elements"] = "Block Elements",
  geometric = "Geometric",
  ["misc-symbols"] = "Misc Symbols",
  currency = "Currency",
  greek = "Greek",
  cyrillic = "Cyrillic",
  ["misc-technical"] = "Technical",
  superscripts = "Superscripts",
  ["number-forms"] = "Number Forms",
  dingbats = "Dingbats",
  ["latin-extended"] = "Latin Extended",
  braille = "Braille"
}

local categoryIcons = {
  recent = "clock"
}
for _, b in unicodeBlocks do
  categoryIcons[b.name] = b.icon
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitSemicolon(s)
  local parts = {}
  for part in string.gmatch(s .. ";", "([^;]*);") do
    table.insert(parts, part)
  end
  return parts
end

local function parseUnicodeData(content)
  local names = {}
  for line in content:gmatch("[^\r\n]+") do
    local parts = splitSemicolon(line)
    if #parts >= 2 then
      local cp = tonumber(parts[1], 16)
      local name = parts[2]
      if cp and name and name ~= "" and not name:find("^<") then
        names[cp] = name
      end
    end
  end
  return names
end

local function parseNameAliases(content, names)
  for line in content:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" and not line:find("^#") then
      local parts = splitSemicolon(line)
      if #parts >= 2 then
        local cp = tonumber(parts[1], 16)
        local alias = parts[2]
        if cp and alias and alias ~= "" and not names[cp] then
          names[cp] = alias
        end
      end
    end
  end
  return names
end

local function downloadDatabase(callback)
  noctalia.log("Unicode Provider: Downloading database from unicode.org...")
  noctalia.runAsync(`mkdir -p '{cacheDir}'`, function()
    noctalia.runAsync(`curl -f -s -S -o '{unicodeDataPath}' '{unicodeDataUrl}'`, function(res)
      if res.exitCode == 0 then
        noctalia.runAsync(`curl -f -s -S -o '{nameAliasesPath}' '{nameAliasesUrl}'`, function(res2)
          if res2.exitCode == 0 then
            callback(true)
          else
            callback(false)
          end
        end)
      else
        callback(false)
      end
    end)
  end)
end

local function loadDb(callback)
  if loading or loaded then return end
  loading = true

  noctalia.runAsync(`test -f '{unicodeDataPath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.log("Unicode Provider: Loading UnicodeData.txt from cache...")
      noctalia.runAsync(`cat '{unicodeDataPath}'`, function(catRes)
        if catRes.exitCode == 0 then
          unicodeNames = parseUnicodeData(catRes.stdout or catRes.body or "")
          noctalia.runAsync(`test -f '{nameAliasesPath}'`, function(res2)
            if res2.exitCode == 0 then
              noctalia.runAsync(`cat '{nameAliasesPath}'`, function(catRes2)
                if catRes2.exitCode == 0 then
                  unicodeNames = parseNameAliases(catRes2.stdout or catRes2.body or "", unicodeNames)
                  namesLoaded = true
                end
                loaded = true
                loading = false
                if callback then callback() end
              end)
            else
              loaded = true
              loading = false
              if callback then callback() end
            end
          end)
        else
          loading = false
        end
      end)
    else
      downloadDatabase(function(success)
        loading = false
        if success then
          loadDb(callback)
        else
          noctalia.log("Unicode Provider: Failed to download database")
        end
      end)
    end
  end)
end

local function loadUsage()
  noctalia.runAsync(`test -f '{usageFilePath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`cat '{usageFilePath}'`, function(catRes)
        local success, parsed = pcall(noctalia.json.decode, catRes.stdout or catRes.body or "")
        if success and type(parsed) == "table" then
          usageCounts = parsed
        end
      end)
    end
  end)
end

loadDb()
loadUsage()

local function saveUsage()
  local payload = noctalia.json.encode(usageCounts)
  noctalia.runAsync(`mkdir -p '{cacheDir}'`, function()
    local escaped = payload:gsub("'", "'\\''")
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{escaped}' '{usageFilePath}'`)
  end)
end

local function recordUsage(ch)
  if not ch or ch == "" then return end
  local d = usageCounts[ch] or { count = 0, lastUsed = 0 }
  usageCounts[ch] = { count = d.count + 1, lastUsed = os.time() }
  saveUsage()
end

local function isValidUnicodeChar(cp)
  return cp >= 0x20 and cp ~= 0x7F and
         not (cp >= 0x80 and cp <= 0x9F) and
         not (cp >= 0xD800 and cp <= 0xDFFF) and
         not (cp >= 0xE000 and cp <= 0xF8FF) and
         cp ~= 0xFFFE and cp ~= 0xFFFF
end

local function makeCharObj(cp, cat)
  local success, char = pcall(utf8.char, cp)
  if not success then char = "" end
  
  local name = unicodeNames[cp] or ""
  local hex = "U+" .. string.upper(string.format("%04X", cp))
  return {
    char = char,
    codePoint = cp,
    hex = hex,
    name = name,
    category = cat
  }
end

local function getCharactersByCategory(cat)
  if cat == "recent" then
    local list = {}
    for ch, data in usageCounts do
      table.insert(list, { char = ch, count = data.count, lastUsed = data.lastUsed })
    end
    table.sort(list, function(a, b)
      if a.lastUsed ~= b.lastUsed then
        return a.lastUsed > b.lastUsed
      end
      return a.count > b.count
    end)
    
    local chars = {}
    for i = 1, math.min(#list, 50) do
      local cp = utf8.codepoint(list[i].char)
      if cp then
        table.insert(chars, makeCharObj(cp, "recent"))
      end
    end
    return chars
  end

  local block = nil
  for _, b in unicodeBlocks do
    if b.name == cat then
      block = b
      break
    end
  end

  if not block then return {} end

  local chars = {}
  for cp = block.start, block["end"] do
    if isValidUnicodeChar(cp) then
      table.insert(chars, makeCharObj(cp, block.name))
    end
  end
  return chars
end

local function search(query)
  if query == "" then
    return getCharactersByCategory("recent")
  end

  local results = {}
  local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local hexQuery = q:gsub("^u%+", "")

  -- Hex codepoint search
  if hexQuery:match("^[0-9a-fA-F]+$") and #hexQuery >= 2 then
    local cp = tonumber(hexQuery, 16)
    if cp and isValidUnicodeChar(cp) and cp <= 0x10FFFF then
      table.insert(results, makeCharObj(cp, "search"))
    end
  end

  -- Name search
  for _, block in unicodeBlocks do
    if block.name:find(q, 1, true) then
      local chars = getCharactersByCategory(block.name)
      for _, c in chars do
        if #results >= 100 then break end
        table.insert(results, c)
      end
    elseif namesLoaded then
      local chars = getCharactersByCategory(block.name)
      for _, c in chars do
        if #results >= 100 then break end
        if c.name and c.name:lower():find(q, 1, true) then
          table.insert(results, c)
        end
      end
    end
    if #results >= 100 then break end
  end

  -- Deduplicate
  local seen = {}
  local filtered = {}
  for _, r in results do
    if r.char ~= "" and not seen[r.char] then
      seen[r.char] = true
      table.insert(filtered, r)
    end
  end

  return filtered
end

local function formatCharEntry(charData)
  local charValue = charData.char
  local title = if charData.name ~= "" then charData.name else charData.hex
  local catName = categoryNames[charData.category] or charData.category
  local desc = if charData.name ~= "" then `{charData.hex} • {catName}` else catName

  return {
    id = `char:{charValue}`,
    title = title,
    subtitle = desc,
    glyph = "code",
    autoPasteText = charValue,
  }
end

function onQuery(query)
  local filter = trim(query)

  if not loaded then
    if loading then
      launcher.setResults(query, {
        {
          id = "loading",
          title = "Loading Unicode database...",
          subtitle = "Parsing UnicodeData.txt...",
          glyph = "loader"
        }
      })
    else
      launcher.setResults(query, {
        {
          id = "not_loaded",
          title = "Database not loaded",
          subtitle = "Press Enter to load Unicode database",
          glyph = "alert-circle"
        }
      })
    end
    return
  end

  local results = {}

  if filter == "" then
    -- Category Selection Switchers
    for _, cat in categories do
      local isSelected = cat == selectedCategory
      local titlePrefix = if isSelected then "● " else "  "
      table.insert(results, {
        id = `cat:{cat}`,
        title = `{titlePrefix}{categoryNames[cat] or cat}`,
        subtitle = `Browse {cat} characters`,
        glyph = categoryIcons[cat] or "category"
      })
    end

    -- Category Items
    local chars = getCharactersByCategory(selectedCategory)
    for _, c in chars do
      table.insert(results, formatCharEntry(c))
    end
  else
    -- Search
    local chars = search(filter)
    for _, c in chars do
      table.insert(results, formatCharEntry(c))
    end
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id == "not_loaded" then
    loadDb(function()
      onQuery("")
    end)
    return
  elseif id:find("cat:", 1, true) == 1 then
    local cat = id:match("^cat:(.*)$")
    if cat then
      selectedCategory = cat
      onQuery("")
    end
    return
  elseif id:find("char:", 1, true) == 1 then
    local ch = id:match("^char:(.*)$")
    if ch then
      recordUsage(ch)
      local escaped = ch:gsub("'", "'\\''")
      noctalia.runAsync(`printf '%s' '{escaped}' | wl-copy`)
      launcher.notify("Unicode Picker", `Copied to clipboard: {ch}`)
    end
  end
end
