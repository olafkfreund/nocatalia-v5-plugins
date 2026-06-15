-- Latency Monitor — background service.

noctalia.setUpdateInterval(1000) -- Tick every second to poll hosts

local hosts = {
	{
		name = "Cloudflare DNS",
		address = "1.1.1.1",
		samples = {},
		lastRtt = -1,
		timedOut = false,
		avg10m = -1,
		avg30m = -1,
		avg60m = -1,
		status = "unknown",
	},
	{
		name = "Google DNS",
		address = "8.8.8.8",
		samples = {},
		lastRtt = -1,
		timedOut = false,
		avg10m = -1,
		avg30m = -1,
		avg60m = -1,
		status = "unknown",
	},
}

local function rttToStatus(rtt, tg, tw)
	if rtt < 0 then
		return "unknown"
	end
	if rtt < tg then
		return "good"
	end
	if rtt < tw then
		return "warning"
	end
	return "critical"
end

local function computeAvg(samples, minutes)
	local cutoff = os.time() - (minutes * 60)
	local sum = 0
	local count = 0
	for _, s in ipairs(samples) do
		if s.ts >= cutoff then
			sum = sum + s.rtt
			count = count + 1
		end
	end
	if count == 0 then
		return -1
	end
	return sum / count
end

local function updateState()
	-- Find worst host
	local order = { critical = 3, warning = 2, good = 1, unknown = 0 }
	local worst = nil
	for _, h in ipairs(hosts) do
		if not worst or (order[h.status] or 0) > (order[worst.status] or 0) then
			worst = h
		end
	end

	-- Send a simplified representation of hosts to avoid cycles or huge table copies
	local hostsSummary = {}
	for _, h in ipairs(hosts) do
		table.insert(hostsSummary, {
			name = h.name,
			address = h.address,
			lastRtt = h.lastRtt,
			timedOut = h.timedOut,
			avg10m = h.avg10m,
			avg30m = h.avg30m,
			avg60m = h.avg60m,
			status = h.status,
		})
	end

	noctalia.state.set("hosts", hostsSummary)
	if worst then
		noctalia.state.set("worstHost", {
			name = worst.name,
			address = worst.address,
			status = worst.status,
			lastRtt = worst.lastRtt,
			avg10m = worst.avg10m,
			timedOut = worst.timedOut,
		})
	else
		noctalia.state.set("worstHost", nil)
	end
end

local function pingHost(host)
	local tg = noctalia.getConfig("thresholdGood") or 20
	local tw = noctalia.getConfig("thresholdWarning") or 70

	host.lastPollTime = os.clock()

	local cmd = `ping -n -c 1 -W 2 {host.address}`
	noctalia.runAsync(cmd, function(res)
		local rtt = -1
		local timedOut = true

		if res.exitCode == 0 and res.stdout ~= "" then
			local m = res.stdout:match("time[=<](%d+%.?%d*)")
			if m then
				rtt = math.round(tonumber(m) or -1)
				if rtt >= 0 then
					timedOut = false
				end
			end
		end

		local now = os.time()
		-- Cutoff older than 65 minutes
		local cutoff = now - (65 * 60)
		local newSamples = {}
		for _, s in ipairs(host.samples) do
			if s.ts >= cutoff then
				table.insert(newSamples, s)
			end
		end

		if not timedOut then
			table.insert(newSamples, { ts = now, rtt = rtt })
			host.lastRtt = rtt
			host.timedOut = false
		else
			host.lastRtt = -1
			host.timedOut = true
		end

		host.samples = newSamples
		host.avg10m = computeAvg(newSamples, 10)
		host.avg30m = computeAvg(newSamples, 30)
		host.avg60m = computeAvg(newSamples, 60)

		if host.timedOut then
			host.status = "critical"
		else
			local a = host.avg10m >= 0 and host.avg10m or host.lastRtt
			host.status = rttToStatus(a, tg, tw)
		end

		updateState()
	end)
end

function update()
	local now = os.clock()
	local intervalSeconds = noctalia.getConfig("intervalSeconds") or 5

	for _, h in ipairs(hosts) do
		if not h.lastPollTime or (now - h.lastPollTime >= intervalSeconds) then
			pingHost(h)
		end
	end
end
