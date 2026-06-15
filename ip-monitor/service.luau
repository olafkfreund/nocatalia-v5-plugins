-- IP Monitor — background service.

noctalia.setUpdateInterval(5000) -- Check check-interval every 5 seconds

local lastFetchTime = 0
local fetchState = "idle" -- idle | loading | success | error
local currentIp = "n/a"
local ipData = nil

local function fetchIp()
	if fetchState == "loading" then
		return
	end
	fetchState = "loading"
	noctalia.state.set("fetchState", "loading")

	local cmd =
		'curl -s -m 10 "http://ip-api.com/json/?fields=status,continent,country,regionName,city,zip,lat,lon,timezone,currency,org,as,query"'
	noctalia.runAsync(cmd, function(res)
		if res.exitCode == 0 and res.stdout ~= "" then
			local ok, data = pcall(function()
				return noctalia.json.decode(res.stdout)
			end)
			if ok and data and data.status == "success" then
				currentIp = data.query or "n/a"
				ipData = {
					ip = data.query or "n/a",
					city = data.city or "n/a",
					country = data.country or "n/a",
					continent = data.continent or "n/a",
					region = data.regionName or "n/a",
					postal = data.zip or "n/a",
					loc = (data.lat and data.lon) and `{data.lat},{data.lon}` or "n/a",
					timezone = data.timezone or "n/a",
					currency = data.currency or "n/a",
					org = data.org or "n/a",
					["as"] = data.as or "n/a",
				}
				fetchState = "success"
				noctalia.state.set("currentIp", currentIp)
				noctalia.state.set("ipData", ipData)
				noctalia.state.set("fetchState", "success")
				lastFetchTime = os.clock()
				return
			end
		end

		currentIp = "n/a"
		ipData = nil
		fetchState = "error"
		noctalia.state.set("currentIp", currentIp)
		noctalia.state.set("ipData", nil)
		noctalia.state.set("fetchState", "error")
		lastFetchTime = os.clock()
	end)
end

noctalia.state.watch("command", function(cmd)
	if cmd == "refresh" then
		fetchIp()
	end
end)

function update()
	local now = os.clock()
	local interval = noctalia.getConfig("refreshInterval") or 300
	if lastFetchTime == 0 or (now - lastFetchTime >= interval) then
		fetchIp()
	end
end
