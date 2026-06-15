-- Special Workspaces — background service.

noctalia.setUpdateInterval(2000) -- Update state every 2 seconds

local function checkWorkspaces()
	noctalia.runAsync("hyprctl -j workspaces", function(wsRes)
		if wsRes.exitCode ~= 0 or wsRes.stdout == "" then
			return
		end
		local ok, wsList = pcall(function()
			return noctalia.json.decode(wsRes.stdout)
		end)
		if not ok or type(wsList) ~= "table" then
			return
		end

		local activeNames = {}
		for _, ws in ipairs(wsList) do
			if ws.name and ws.name:sub(1, 8) == "special:" then
				activeNames[ws.name] = true
			end
		end
		noctalia.state.set("activeWorkspaceNames", activeNames)
	end)

	noctalia.runAsync("hyprctl -j monitors", function(monRes)
		if monRes.exitCode ~= 0 or monRes.stdout == "" then
			return
		end
		local ok, monList = pcall(function()
			return noctalia.json.decode(monRes.stdout)
		end)
		if not ok or type(monList) ~= "table" then
			return
		end

		local activeSpecial = {}
		for _, mon in ipairs(monList) do
			if
				mon.name
				and mon.specialWorkspace
				and mon.specialWorkspace.name
				and mon.specialWorkspace.name:sub(1, 8) == "special:"
			then
				activeSpecial[mon.name] = mon.specialWorkspace.name
			end
		end
		noctalia.state.set("activeSpecialByMonitor", activeSpecial)
	end)
end

noctalia.state.watch("command", function(cmd)
	if not cmd or type(cmd) ~= "table" then
		return
	end

	if cmd.action == "toggle" then
		local wsName = cmd.workspace
		if wsName:sub(1, 8) == "special:" then
			wsName = wsName:sub(9)
		end
		noctalia.runAsync(`hyprctl dispatch togglespecialworkspace '{wsName}'`, function()
			checkWorkspaces()
		end)
	elseif cmd.action == "toggle_active" then
		noctalia.runAsync("hyprctl dispatch togglespecialworkspace", function()
			checkWorkspaces()
		end)
	elseif cmd.action == "refresh" then
		checkWorkspaces()
	end
end)

function update()
	checkWorkspaces()
end
