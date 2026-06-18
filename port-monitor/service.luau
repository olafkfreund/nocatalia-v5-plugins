-- service.luau: Port Monitor background service
-- Polls ss for listening TCP/UDP ports and publishes state to widgets

local refreshInterval = noctalia.settings.get("refreshInterval") or 5
local hideSystemPorts = noctalia.settings.get("hideSystemPorts") or false

-- Set polling interval in milliseconds
noctalia.setUpdateInterval(refreshInterval * 1000)

-- Parse ss output: returns a list of unique port numbers
local function parseSs(text)
	local ports = {}
	local seen = {}
	for line in text:gmatch("[^\n]+") do
		-- Skip header lines
		if not line:match("^State") and not line:match("^Netid") then
			local parts = {}
			for w in line:gmatch("%S+") do
				parts[#parts + 1] = w
			end
			if #parts >= 4 then
				local localAddr = parts[4]
				local lastColon = localAddr:find(":[^:]*$")
				if lastColon then
					local port = tonumber(localAddr:sub(lastColon + 1))
					if port then
						local key = tostring(port)
						if not seen[key] then
							seen[key] = true
							ports[#ports + 1] = port
						end
					end
				end
			end
		end
	end
	return ports
end

-- Build a JSON array string from a table of numbers
local function toJsonArray(tbl)
	local parts = {}
	for i = 1, #tbl do
		parts[i] = tostring(tbl[i])
	end
	return "[" .. table.concat(parts, ",") .. "]"
end

-- Main scan callback
local function onScanDone(output)
	local allPorts = parseSs(output)

	-- Filter system ports if requested
	if hideSystemPorts then
		local filtered = {}
		for i = 1, #allPorts do
			if allPorts[i] >= 1024 then
				filtered[#filtered + 1] = allPorts[i]
			end
		end
		allPorts = filtered
	end

	local count = #allPorts

	-- Publish state for widgets to consume
	noctalia.state.set("portCount", count)
	noctalia.state.set("portList", toJsonArray(allPorts))
end

-- Watch for setting changes so interval can be respected at next update
noctalia.state.watch("refreshInterval", function(val)
	local n = tonumber(val)
	if n and n > 0 then
		noctalia.setUpdateInterval(n * 1000)
	end
end)

-- update() is called by the runtime on each interval tick
function update()
	-- Reload settings each tick in case user changed them
	hideSystemPorts = noctalia.settings.get("hideSystemPorts") or false
	-- Run both ss commands; combine output in a single shell call
	noctalia.runAsync("ss -tlnp 2>/dev/null; ss -ulnp 2>/dev/null", onScanDone)
end
