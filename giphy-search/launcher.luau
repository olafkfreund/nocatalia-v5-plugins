-- Giphy Search — launcher provider.
-- Searches for GIFs on Giphy and allows copying their URLs.

local lastQuery = ""
local currentResults = {}

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
  local apiKey = launcher.getConfig("api_key") or ""
  local rating = launcher.getConfig("rating") or "g"

  if apiKey == "" then
    lastQuery = ""
    currentResults = {}
    launcher.setResults(query, {
      {
        id = "error_api_key",
        title = tr("launcher.noApiKey"),
        subtitle = tr("launcher.noApiKeyDescription"),
        glyph = "alert-triangle"
      }
    })
    return
  end

  if filter == "" then
    lastQuery = ""
    currentResults = {}
    launcher.setResults(query, {
      {
        id = "hint_type_something",
        title = tr("launcher.typeSomething"),
        subtitle = tr("launcher.searchGiphy"),
        glyph = "gif"
      }
    })
    return
  end

  local results = {}
  table.insert(results, {
    id = "search:" .. filter,
    title = tr("launcher.search", { query = filter }),
    subtitle = tr("launcher.openOnGiphy"),
    glyph = "gif"
  })

  if filter == lastQuery then
    for _, item in ipairs(currentResults) do
      table.insert(results, item)
    end
    launcher.setResults(query, results)
    return
  end

  launcher.setResults(query, results)
  lastQuery = filter

  local escapedApiKey = urlEncode(apiKey)
  local escapedQuery = urlEncode(filter)
  local escapedRating = urlEncode(rating)

  local cmd = "curl -s \"https://api.giphy.com/v1/gifs/search?api_key=" .. escapedApiKey .. "&q=" .. escapedQuery .. "&limit=20&rating=" .. escapedRating .. "\""

  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local stdout = res.stdout or res.body or ""
      local success, data = pcall(noctalia.json.decode, stdout)
      if success and data and data.data then
        currentResults = {}
        for _, gif in ipairs(data.data) do
          local previewUrl = ""
          if gif.images then
            if gif.images.fixed_height and gif.images.fixed_height.url then
              previewUrl = gif.images.fixed_height.url
            elseif gif.images.fixed_width and gif.images.fixed_width.url then
              previewUrl = gif.images.fixed_width.url
            end
          end
          local originalUrl = gif.url
          if gif.images and gif.images.original and gif.images.original.url then
            originalUrl = gif.images.original.url
          end

          local title = gif.title
          if not title or title == "" then
            title = tr("launcher.untitled")
          end

          table.insert(currentResults, {
            id = "gif:" .. originalUrl,
            title = title,
            subtitle = tr("launcher.copyUrl"),
            glyph = (previewUrl ~= "" and previewUrl or "gif")
          })
        end

        if filter == lastQuery then
          onQuery(query)
        end
      end
    end
  end)
end

function onActivate(id)
  if id:sub(1, 7) == "search:" then
    local filter = id:sub(8)
    local escapedQuery = urlEncode(filter)
    noctalia.runAsync("xdg-open 'https://giphy.com/search/" .. escapedQuery .. "'")
  elseif id:sub(1, 4) == "gif:" then
    local originalUrl = id:sub(5)
    local escaped = originalUrl:gsub("'", "'\\''")
    noctalia.runAsync("printf '%s' '" .. escaped .. "' | wl-copy", function(res)
      if res.exitCode == 0 then
        launcher.notify("Giphy Search", "Copied GIF URL to clipboard!")
      end
    end)
  end
end
