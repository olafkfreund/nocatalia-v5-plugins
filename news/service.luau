-- News — background service.
-- Fetches headlines from NewsAPI.org via curl and rotates through them.

local headlines = {}
local currentIndex = 1
local isLoading = false
local errorMsg = ""

local function updateState()
  local current = headlines[currentIndex] or ""
  noctalia.state.set("currentHeadline", current)
  noctalia.state.set("headlineCount", #headlines)
  noctalia.state.set("currentIndex", currentIndex)
  noctalia.state.set("isLoading", isLoading)
  noctalia.state.set("errorMsg", errorMsg)
end

local function advanceHeadline()
  if #headlines == 0 then return end
  currentIndex = (currentIndex % #headlines) + 1
  updateState()
end

local function fetchNews()
  local apiKey = noctalia.getConfig("apiKey") or ""
  if apiKey == "" or apiKey == "YOUR_API_KEY_HERE" then
    errorMsg = "API key not configured"
    updateState()
    return
  end

  local country = noctalia.getConfig("country") or "us"
  local category = noctalia.getConfig("category") or "general"
  local maxH = tonumber(noctalia.getConfig("maxHeadlines")) or 10

  local url = "https://newsapi.org/v2/top-headlines?country=" .. country
    .. "&category=" .. category
    .. "&pageSize=" .. maxH
    .. "&apiKey=" .. apiKey

  isLoading = true
  updateState()

  noctalia.runAsync('curl -s --max-time 15 "' .. url .. '" 2>/dev/null', function(res)
    isLoading = false
    if res.exitCode ~= 0 then
      errorMsg = "Fetch failed"
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    local newHeadlines = {}
    for title in text:gmatch('"title":"([^"]+)"') do
      title = title:gsub("\\n", " "):gsub("\\\"", '"')
      newHeadlines[#newHeadlines + 1] = title
    end
    if #newHeadlines > 0 then
      headlines = newHeadlines
      currentIndex = 1
      errorMsg = ""
    else
      errorMsg = "No headlines found"
    end
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    fetchNews()
  elseif cmd == "next" then
    advanceHeadline()
  elseif cmd == "prev" then
    if #headlines > 0 then
      currentIndex = ((currentIndex - 2) % #headlines) + 1
    end
    updateState()
  end
end)

fetchNews()

local refreshMs = (tonumber(noctalia.getConfig("refreshInterval")) or 30) * 60 * 1000
noctalia.setUpdateInterval(refreshMs)

function onUpdate()
  fetchNews()
end
