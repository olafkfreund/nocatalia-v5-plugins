-- DNS Switcher — background service.
-- Periodically checks connection DNS IP and handles commands to change it.

noctalia.setUpdateInterval(10000) -- Check DNS every 10 seconds

local defaultProviders = {
	{ id = "google", label = "Google", ip = "8.8.8.8 8.8.4.4" },
	{ id = "cloudflare", label = "Cloudflare", ip = "1.1.1.1 1.0.0.1" },
	{ id = "opendns", label = "OpenDNS", ip = "208.67.222.222 208.67.220.220" },
	{ id = "adguard", label = "AdGuard", ip = "94.140.14.14 94.140.15.15" },
	{ id = "quad9", label = "Quad9", ip = "9.9.9.9 149.112.112.112" },
}

local ipLookup = {
	["8.8.8.8"] = "google",
	["8.8.4.4"] = "google",
	["1.1.1.1"] = "cloudflare",
	["1.0.0.1"] = "cloudflare",
	["208.67.222.222"] = "opendns",
	["208.67.220.220"] = "opendns",
	["94.140.14.14"] = "adguard",
	["94.140.15.15"] = "adguard",
	["9.9.9.9"] = "quad9",
	["149.112.112.112"] = "quad9",
}

local customProviders = {}
local customLoaded = false
local isChanging = false

local function validateDnsInput(ipString)
	local trimmed = ipString:gsub("^%s+", ""):gsub("%s+$", "")
	local parts = {}
	for p in trimmed:gmatch("%S+") do
		table.insert(parts, p)
	end
	if #parts < 1 or #parts > 2 then
		return false
	end
	for _, part in ipairs(parts) do
		local octets = {}
		for oct in part:gmatch("%d+") do
			table.insert(octets, tonumber(oct))
		end
		if #octets ~= 4 then
			return false
		end
		for _, oct in ipairs(octets) do
			if oct < 0 or oct > 255 then
				return false
			end
		end
		if not part:match("^%d+%.%d+%.%d+%.%d+$") then
			return false
		end
	end
	return true
end

local function checkDns()
	if isChanging then
		return
	end

	noctalia.runAsync("nmcli -f IP4.DNS dev show | head -n 1 | awk '{print $2}'", function(res)
		if res.exitCode ~= 0 then
			return
		end
		local rawIp = (res.stdout or ""):gsub("[\r\n]+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		noctalia.state.set("currentDnsIp", rawIp)

		-- Check default providers
		local parts = {}
		for part in rawIp:gmatch("[^%s,]+") do
			table.insert(parts, part)
		end

		for _, part in ipairs(parts) do
			local id = ipLookup[part]
			if id then
				noctalia.state.set("activeProviderId", id)
				local label = ""
				for _, p in ipairs(defaultProviders) do
					if p.id == id then
						label = p.label
						break
					end
				end
				noctalia.state.set("currentDnsName", label)
				noctalia.state.set("isCustomDns", true)
				return
			end
		end

		-- Check custom providers
		for idx, srv in ipairs(customProviders) do
			local srvIps = {}
			for part in srv.ip:gmatch("%S+") do
				table.insert(srvIps, part)
			end
			for _, sip in ipairs(srvIps) do
				for _, part in ipairs(parts) do
					if sip == part then
						noctalia.state.set("activeProviderId", "custom_" .. tostring(idx))
						noctalia.state.set("currentDnsName", srv.label)
						noctalia.state.set("isCustomDns", true)
						return
					end
				end
			end
		end

		-- Default/ISP
		if rawIp == "" or rawIp:match("^192%.168%.") or rawIp:match("^127%.") then
			noctalia.state.set("activeProviderId", "default")
			noctalia.state.set("currentDnsName", "Default (ISP)")
			noctalia.state.set("isCustomDns", false)
			return
		end

		-- Unknown custom IP
		noctalia.state.set("activeProviderId", "unknown")
		noctalia.state.set("currentDnsName", "Custom (" .. rawIp .. ")")
		noctalia.state.set("isCustomDns", true)
	end)
end

local function loadCustom()
	local home = os.getenv("HOME") or "/tmp"
	local dir = `{home}/.cache/noctalia/plugins/dns-switcher`
	local path = `{dir}/custom.json`
	noctalia.runAsync(`cat '{path}' 2>/dev/null`, function(res)
		if res.exitCode == 0 and res.stdout ~= "" then
			local ok, data = pcall(function()
				return noctalia.json.decode(res.stdout)
			end)
			if ok and type(data) == "table" and type(data.servers) == "table" then
				customProviders = data.servers
			end
		end
		customLoaded = true
		noctalia.state.set("customProviders", customProviders)
		checkDns()
	end)
end

local function saveCustom()
	if not customLoaded then
		return
	end
	local home = os.getenv("HOME") or "/tmp"
	local dir = `{home}/.cache/noctalia/plugins/dns-switcher`
	local path = `{dir}/custom.json`
	local payload = noctalia.json.encode({ servers = customProviders })
	noctalia.runAsync(`mkdir -p '{dir}'`, function(res)
		noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{payload:gsub("'", "'\\''")}' '{path}'`)
	end)
	noctalia.state.set("customProviders", customProviders)
end

local function setDns(payload)
	if isChanging then
		return
	end

	local dnsIp = payload
	local preset
	for _, p in ipairs(defaultProviders) do
		if p.id == payload then
			preset = p
			break
		end
	end
	if preset then
		dnsIp = preset.ip
	elseif payload == "default" then
		dnsIp = ""
	end

	if dnsIp ~= "" and not validateDnsInput(dnsIp) then
		noctalia.state.set("lastError", "Invalid IP address")
		return
	end

	isChanging = true
	noctalia.state.set("isChanging", true)
	noctalia.state.set("lastError", "")
	noctalia.state.set("currentDnsName", "Switching...")

	local safeIp = dnsIp:gsub("[^%d%. ]", "")

	local cmd
	if safeIp == "" then
		cmd = "CON=$(nmcli -t -f NAME connection show --active | head -n 1); "
			.. 'if [ -z "$CON" ]; then exit 1; fi; '
			.. 'nmcli con mod "$CON" ipv4.dns "" ipv4.ignore-auto-dns no; '
			.. 'nmcli con up "$CON"'
	else
		cmd = "CON=$(nmcli -t -f NAME connection show --active | head -n 1); "
			.. 'if [ -z "$CON" ]; then exit 1; fi; '
			.. 'nmcli con mod "$CON" ipv4.dns "'
			.. safeIp
			.. '" ipv4.ignore-auto-dns yes; '
			.. 'nmcli con up "$CON"'
	end

	noctalia.runAsync(`pkexec sh -c '{cmd}'`, function(res)
		isChanging = false
		noctalia.state.set("isChanging", false)
		if res.exitCode ~= 0 then
			noctalia.state.set("lastError", "Failed to apply DNS")
		else
			noctalia.state.set("lastError", "")
		end
		checkDns()
	end)
end

noctalia.state.watch("command", function(cmd)
	if not cmd then
		return
	end
	if type(cmd) == "table" then
		if cmd.action == "set" then
			setDns(cmd.ip)
		elseif cmd.action == "add" then
			if validateDnsInput(cmd.ip) then
				table.insert(customProviders, { label = cmd.label, ip = cmd.ip, isCustom = true })
				saveCustom()
				checkDns()
			end
		elseif cmd.action == "remove" then
			local idx = tonumber(cmd.index)
			if idx and idx >= 1 and idx <= #customProviders then
				table.remove(customProviders, idx)
				saveCustom()
				checkDns()
			end
		elseif cmd.action == "refresh" then
			checkDns()
		end
	elseif type(cmd) == "string" then
		if cmd == "refresh" then
			checkDns()
		else
			setDns(cmd)
		end
	end
end)

-- Initial check
loadCustom()

function update()
	checkDns()
end
