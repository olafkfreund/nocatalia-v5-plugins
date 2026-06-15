-- Display Settings — background service.

noctalia.setUpdateInterval(5000) -- Check display config every 5 seconds

local function parseWlrRandr(stdout)
	local list = {}
	local current = nil

	for line in stdout:gmatch("[^\r\n]+") do
		local name, desc = line:match('^([%w%.%-]+)%s*"([^"]+)"')
		if name then
			if current then
				table.insert(list, current)
			end
			current = {
				name = name,
				model = desc,
				enabled = false,
				scale = 1.0,
				transform = "Normal",
				vrr_supported = false,
				vrr_enabled = false,
				current_mode = "unknown",
			}
		elseif current then
			local model = line:match("Model:%s*(.*)")
			if model then
				current.model = model
			end

			local enabled = line:match("Enabled:%s*(.*)")
			if enabled then
				current.enabled = enabled == "yes"
			end

			local trans = line:match("Transform:%s*(.*)")
			if trans then
				current.transform = trans
			end

			local scale = line:match("Scale:%s*(.*)")
			if scale then
				current.scale = tonumber(scale) or 1.0
			end

			local vrr = line:match("Adaptive Sync:%s*(.*)")
			if vrr then
				current.vrr_supported = vrr ~= "not supported"
				current.vrr_enabled = vrr == "enabled"
			end

			local w, h, hz = line:match("([%d]+)x([%d]+)%s*px,%s*([%d%.]+)%s*Hz.*current")
			if w and h and hz then
				current.current_mode = `{w}x{h}@{math.round(tonumber(hz) or 60)}Hz`
			end
		end
	end
	if current then
		table.insert(list, current)
	end
	return list
end

local function checkOutputs()
	noctalia.runAsync("niri msg -j outputs", function(res)
		if res.exitCode == 0 and res.stdout ~= "" then
			local ok, data = pcall(function()
				return noctalia.json.decode(res.stdout)
			end)
			if ok and type(data) == "table" then
				local outputs = {}
				for name, details in pairs(data) do
					local currentMode = "unknown"
					if details.current_mode and details.modes and details.modes[details.current_mode + 1] then
						local mode = details.modes[details.current_mode + 1]
						local hz = math.round((mode.refresh_rate or 60000) / 1000)
						currentMode = `{mode.width}x{mode.height}@{hz}Hz`
					end

					local logical = details.logical or {}
					table.insert(outputs, {
						name = name,
						model = details.model or details.name or name,
						enabled = details.logical ~= nil,
						scale = logical.scale or 1.0,
						transform = logical.transform or "Normal",
						vrr_supported = details.vrr_supported == true,
						vrr_enabled = details.vrr_enabled == true,
						current_mode = currentMode,
					})
				end
				noctalia.state.set("outputs", outputs)
				noctalia.state.set("compositor", "niri")
				return
			end
		end

		-- Fallback to wlr-randr
		noctalia.runAsync("wlr-randr", function(wlrRes)
			if wlrRes.exitCode == 0 and wlrRes.stdout ~= "" then
				local outputs = parseWlrRandr(wlrRes.stdout)
				noctalia.state.set("outputs", outputs)
				noctalia.state.set("compositor", "wlr")
			else
				noctalia.state.set("outputs", {})
				noctalia.state.set("compositor", "unknown")
			end
		end)
	end)
end

noctalia.state.watch("command", function(cmd)
	if not cmd or type(cmd) ~= "table" then
		return
	end

	local targetCmd = ""
	if cmd.action == "scale" then
		targetCmd = `niri msg output '{cmd.output}' scale {cmd.value}`
	elseif cmd.action == "transform" then
		targetCmd = `niri msg output '{cmd.output}' transform {cmd.value}`
	elseif cmd.action == "vrr" then
		local vrrVal = cmd.value and "on" or "off"
		targetCmd = `niri msg output '{cmd.output}' vrr {vrrVal}`
	elseif cmd.action == "power" then
		local powerVal = cmd.value and "on" or "off"
		targetCmd = `niri msg output '{cmd.output}' {powerVal}`
	elseif cmd.action == "refresh" then
		checkOutputs()
		return
	end

	if targetCmd ~= "" then
		noctalia.runAsync(targetCmd, function(res)
			checkOutputs()
		end)
	end
end)

function update()
	checkOutputs()
end
