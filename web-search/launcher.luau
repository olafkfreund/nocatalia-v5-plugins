-- Web Search — launcher provider.
-- Search the internet and get search suggestions in real-time.

local engines = {
  Google = {
    search = "https://www.google.com/search?q=",
    suggest = "https://suggestqueries.google.com/complete/search?client=chrome&q="
  },
  DuckDuckGo = {
    search = "https://duckduckgo.com/?q=",
    suggest = "https://duckduckgo.com/ac/?q="
  },
  Bing = {
    search = "https://www.bing.com/search?q=",
    suggest = "https://www.bing.com/osjson.aspx?query="
  },
  Brave = {
    search = "https://search.brave.com/search?q=",
    suggest = "https://search.brave.com/api/suggest?q="
  },
  Yandex = {
    search = "https://yandex.com/search/?text=",
    suggest = "https://suggest.yandex.com/suggest-ya.cgi?v=4&part="
  }
}

local lastQuery = ""
local suggestions = {}

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
    for k, v in replacements do
      val = val:gsub("{" .. k .. "}", tostring(v))
    end
  end
  return val
end

local function isUrl(text)
  if not text or text:find("%s") then return false end
  
  if text:find("^%a%w*://") then return true end
  if text:lower():find("^localhost") then return true end
  
  local parts = {}
  for part in text:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  if #parts >= 2 then
    local last = parts[#parts]
    if #last >= 2 and last:match("^%a+$") then
      return true
    end
    local isIp = true
    for _, part in parts do
      if not part:match("^%d+$") or tonumber(part) > 255 then
        isIp = false
        break
      end
    end
    if isIp and #parts == 4 then return true end
  end
  
  return false
end

local function normalizeUrl(text)
  text = trim(text)
  if text:find("^%a%w*://") then
    return text
  end
  if text:lower():find("^localhost") or text:match("^%d+%.%d+%.%d+%.%d+") then
    return "http://" .. text
  end
  return "https://" .. text
end

local function parseSuggestions(engineName, body)
  local success, parsed = pcall(noctalia.json.decode, body)
  if not success or type(parsed) ~= "table" then
    return {}
  end

  local list = {}
  if engineName == "DuckDuckGo" then
    for _, item in parsed do
      if type(item) == "table" and type(item.phrase) == "string" then
        table.insert(list, item.phrase)
      end
    end
  else
    local suggs = parsed[2]
    if type(suggs) == "table" then
      for _, s in suggs do
        if type(s) == "string" then
          table.insert(list, s)
        end
      end
    end
  end
  return list
end

function onQuery(query)
  local filter = trim(query)
  
  local engineName = launcher.getConfig("search_engine") or "Google"
  local showSuggestions = launcher.getConfig("show_suggestions") ~= false
  local maxResults = tonumber(launcher.getConfig("max_results")) or 5
  local directUrl = launcher.getConfig("direct_url") ~= false

  local engine = engines[engineName] or engines.Google

  if filter == "" then
    launcher.setResults(query, {
      {
        id = "hint",
        title = tr("launcher.typeSomething"),
        subtitle = tr("launcher.searchInternet", { engine = engineName }),
        glyph = "search"
      }
    })
    return
  end

  local results = {}

  if directUrl and isUrl(filter) then
    local url = normalizeUrl(filter)
    table.insert(results, {
      id = `url:{url}`,
      title = tr("launcher.openUrl", { url = url }),
      subtitle = tr("launcher.openUrlDescription"),
      glyph = "link"
    })
  end

  table.insert(results, {
    id = `search:{filter}`,
    title = tr("launcher.search", { query = filter }),
    subtitle = tr("launcher.openIn", { engine = engineName }),
    glyph = "world"
  })

  if showSuggestions and filter == lastQuery then
    for i, s in ipairs(suggestions) do
      if i > maxResults then break end
      table.insert(results, {
        id = `suggest:{s}`,
        title = s,
        subtitle = tr("launcher.suggestion", { engine = engineName }),
        glyph = "search"
      })
    end
  end

  launcher.setResults(query, results)

  if showSuggestions and filter ~= lastQuery and #filter > 1 then
    lastQuery = filter
    local url = engine.suggest .. urlEncode(filter)
    noctalia.http({ url = url }, function(res)
      if res.ok then
        suggestions = parseSuggestions(engineName, res.body)
        onQuery(query)
      end
    end)
  end
end

function onActivate(id)
  if id:find("url:", 1, true) == 1 then
    local url = id:match("^url:(.*)$")
    if url then
      local escaped = url:gsub("'", "'\\''")
      noctalia.runAsync(`xdg-open '{escaped}'`)
    end
  elseif id:find("search:", 1, true) == 1 then
    local q = id:match("^search:(.*)$")
    if q then
      local engineName = launcher.getConfig("search_engine") or "Google"
      local engine = engines[engineName] or engines.Google
      local url = engine.search .. urlEncode(q)
      local escaped = url:gsub("'", "'\\''")
      noctalia.runAsync(`xdg-open '{escaped}'`)
    end
  elseif id:find("suggest:", 1, true) == 1 then
    local s = id:match("^suggest:(.*)$")
    if s then
      local engineName = launcher.getConfig("search_engine") or "Google"
      local engine = engines[engineName] or engines.Google
      local url = engine.search .. urlEncode(s)
      local escaped = url:gsub("'", "'\\''")
      noctalia.runAsync(`xdg-open '{escaped}'`)
    end
  end
end
