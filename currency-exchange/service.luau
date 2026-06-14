-- Currency Exchange — background service.
-- Periodically fetches latest rates and exposes them via state.

noctalia.setUpdateInterval(5000) -- poll interval configuration every 5 seconds

local lastFetchTime = 0

local function fetchRates()
  noctalia.state.set("loading", true)
  local url = "https://api.frankfurter.app/latest?from=USD"

  noctalia.http({ url = url }, function(res)
    noctalia.state.set("loading", false)
    if not res.ok then
      noctalia.log(`CurrencyEx: API failed. Status: {res.status}`)
      return
    end

    local ok, response = pcall(noctalia.json.decode, res.body)
    if not ok or type(response) ~= "table" or not response.rates then
      noctalia.log("CurrencyEx: API error response or missing rates")
      return
    end

    -- Add USD as base (1.0)
    response.rates["USD"] = 1.0
    noctalia.state.set("rates", response.rates)
    noctalia.state.set("last_update", os.date("%H:%M"))
    noctalia.state.set("loaded", true)
  end)
end

local function poll()
  local now = os.clock()
  local refreshMins = noctalia.getConfig("refreshInterval") or 60
  local refreshInterval = refreshMins * 60

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    fetchRates()
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    noctalia.state.set("command", nil)
    lastFetchTime = os.clock()
    fetchRates()
  end
end)

function update()
  poll()
end
