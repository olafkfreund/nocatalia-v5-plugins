-- Steam Price Watcher — background service.
-- Checks Steam game prices via the Steam Store API.

local dealsCount = 0
local dealsSummary = ""
local lastChecked = ""

local function updateState()
  noctalia.state.set("dealsCount", dealsCount)
  noctalia.state.set("dealsSummary", dealsSummary)
  noctalia.state.set("lastChecked", lastChecked)
end

local function checkPrices()
  local watchlistStr = noctalia.getConfig("watchlist") or "[]"
  local currency = noctalia.getConfig("currency") or "us"
  local symbol = noctalia.getConfig("currencySymbol") or "$"

  -- Simple JSON parsing for watchlist array
  local deals = {}
  local appids = {}
  local targets = {}
  local names = {}

  for appid, name, targetStr in watchlistStr:gmatch('"appid"[:%s]+"?(%d+)"?[^}]+"name"[:%s]+"([^"]+)"[^}]+"targetPrice"[:%s]+(%-?[%d%.]+)') do
    appids[#appids + 1] = appid
    names[appid] = name
    targets[appid] = tonumber(targetStr) or 0
  end

  if #appids == 0 then
    updateState()
    return
  end

  local url = "https://store.steampowered.com/api/appdetails?appids=" .. table.concat(appids, ",") .. "&cc=" .. currency
  local cmd = 'curl -s --max-time 15 "' .. url .. '" 2>/dev/null'

  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then return end
    local text = res.stdout or res.body or ""
    local dealsFound = 0
    local summaryParts = {}

    for _, appid in ipairs(appids) do
      local price = text:match('"' .. appid .. '".*?"final":(%d+)')
      if price then
        local priceFloat = tonumber(price) / 100
        local target = targets[appid] or 0
        if priceFloat <= target then
          dealsFound = dealsFound + 1
          summaryParts[#summaryParts + 1] = names[appid] .. ": " .. symbol .. string.format("%.2f", priceFloat)
        end
      end
    end

    dealsCount = dealsFound
    dealsSummary = table.concat(summaryParts, " | ")
    lastChecked = os.date("%H:%M")
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    checkPrices()
  end
end)

checkPrices()

local interval = (tonumber(noctalia.getConfig("checkInterval")) or 30) * 60 * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  checkPrices()
end
