-- System Info — background service.

noctalia.setUpdateInterval(1000) -- Tick every second to manage intervals

local last10sUpdate = 0
local last60sUpdate = 0
local runOnceDone = false

local sysInfo = {
	distro = nil,
	kernel = nil,
	uptime = nil,
	cpuUsage = nil,
	cpuTemp = nil,
	memUsage = nil,
	rootDisk = nil,
	homeDisk = nil,
	lanAddress = nil,
	ipAddress = nil,
}

local function trim(s)
	if not s then return "" end
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function updateState()
	local copy = {
		distro = sysInfo.distro,
		kernel = sysInfo.kernel,
		uptime = sysInfo.uptime,
		cpuUsage = sysInfo.cpuUsage,
		cpuTemp = sysInfo.cpuTemp,
		memUsage = sysInfo.memUsage,
		rootDisk = sysInfo.rootDisk,
		homeDisk = sysInfo.homeDisk,
		lanAddress = sysInfo.lanAddress,
		ipAddress = sysInfo.ipAddress,
	}
	noctalia.state.set("sysInfo", copy)
end

local function fetchOnce()
	if runOnceDone then
		return
	end
	runOnceDone = true

	noctalia.runAsync("grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '\\\"'", function(res)
		if res.exitCode == 0 then
			sysInfo.distro = trim(res.stdout)
			updateState()
		end
	end)

	noctalia.runAsync("uname -r", function(res)
		if res.exitCode == 0 then
			sysInfo.kernel = trim(res.stdout)
			updateState()
		end
	end)
end

local function fetch10s()
	noctalia.runAsync(
		"uptime -p | sed 's/up //; s/ days*/d/; s/ hours*/h/; s/ minutes*/m/; s/,//g'",
		function(res)
			if res.exitCode == 0 then
				sysInfo.uptime = trim(res.stdout)
				updateState()
			end
		end
	)

	noctalia.runAsync("top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4\"%\"}'", function(res)
		if res.exitCode == 0 then
			sysInfo.cpuUsage = trim(res.stdout)
			updateState()
		end
	end)

	noctalia.runAsync("sensors | grep 'Package id 0' | awk '{print $4}' | tr -d '+'", function(res)
		if res.exitCode == 0 and trim(res.stdout) ~= "" then
			sysInfo.cpuTemp = trim(res.stdout)
		else
			sysInfo.cpuTemp = ""
		end
		updateState()
	end)

	noctalia.runAsync("free -h | awk '/Mem:/ {print $3 \" / \" $2}'", function(res)
		if res.exitCode == 0 then
			sysInfo.memUsage = trim(res.stdout)
			updateState()
		end
	end)

	noctalia.runAsync("df -h / | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'", function(res)
		if res.exitCode == 0 then
			sysInfo.rootDisk = trim(res.stdout)
			updateState()
		end
	end)

	noctalia.runAsync("df -h /home | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'", function(res)
		if res.exitCode == 0 then
			sysInfo.homeDisk = trim(res.stdout)
			updateState()
		end
	end)
end

local function fetch60s()
	noctalia.runAsync(
		"ip -4 addr show scope global | awk '/inet/ {print $2}' | head -n 1 | cut -d/ -f1",
		function(res)
			if res.exitCode == 0 then
				sysInfo.lanAddress = trim(res.stdout)
				updateState()
			end
		end
	)

	noctalia.runAsync("curl -s ifconfig.me", function(res)
		if res.exitCode == 0 then
			sysInfo.ipAddress = trim(res.stdout)
			updateState()
		end
	end)
end

-- Refresh command listener
noctalia.state.watch("command", function(cmd)
	if cmd == "refresh" then
		fetchOnce()
		fetch10s()
		fetch60s()
	end
end)

function update()
	local now = os.time()
	fetchOnce() -- Will run once due to guard variable

	if now - last10sUpdate >= 10 then
		last10sUpdate = now
		fetch10s()
	end

	if now - last60sUpdate >= 60 then
		last60sUpdate = now
		fetch60s()
	end
end
