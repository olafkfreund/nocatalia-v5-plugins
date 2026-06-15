-- Dmenu Provider — background service.

noctalia.setUpdateInterval(0)

local sessionId = 0

local function normalizeItems(arr)
	local list = {}
	for idx, item in ipairs(arr) do
		if type(item) == "string" then
			table.insert(list, { name = item, value = item, index = idx - 1 })
		elseif type(item) == "table" then
			table.insert(list, {
				name = item.name or item.label or item.value or `Item {idx}`,
				description = item.description or "",
				value = item.value or item.name or item.label or "",
				icon = item.icon or "",
				image = item.image or "",
				index = idx - 1,
			})
		end
	end
	return list
end

local function parseItems(input, separator)
	local list = {}
	local sep = separator or "\n"
	sep = sep:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\r", "\r")

	local idx = 0
	-- Use pattern matching to split lines
	for line in input:gmatch("[^\r\n]+") do
		local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" then
			table.insert(list, {
				name = trimmed,
				value = trimmed,
				index = idx,
			})
			idx = idx + 1
		end
	end
	return list
end

local function handleSelection(value, index)
	local resultFile = noctalia.state.get("dmenu_resultFile") or "/tmp/noctalia-dmenu-result"
	local resultFormat = noctalia.state.get("dmenu_resultFormat") or "plain"
	local callbackCmd = noctalia.state.get("dmenu_callbackCmd") or ""
	local closeOnSelect = noctalia.state.get("dmenu_closeOnSelect") ~= false
	local showToast = noctalia.getConfig("showToastOnSelect") == true

	local resultStr = value
	if resultFormat == "json" then
		resultStr = noctalia.json.encode({
			value = value,
			index = index,
			sessionId = noctalia.state.get("dmenu_sessionId") or 0,
		})
	elseif resultFormat == "index" then
		resultStr = tostring(index)
	end

	local escaped = resultStr:gsub("'", "'\\''")
	local escapedFile = resultFile:gsub("'", "'\\''")
	local cmd = `printf '%s' '{escaped}' > '{escapedFile}.tmp' && mv '{escapedFile}.tmp' '{escapedFile}'`

	noctalia.runAsync(`sh -c '{cmd}'`, function(res)
		if showToast then
			noctalia.notify("Dmenu Selector", `Selected: {value}`)
		end

		if callbackCmd ~= "" then
			local runCmd = callbackCmd:gsub("{}", resultStr):gsub("{value}", resultStr):gsub("{index}", tostring(index))
			noctalia.runAsync(`sh -c '{runCmd}'`)
		end
	end)

	if closeOnSelect then
		noctalia.runAsync("noctalia msg panel-toggle launcher")
	end

	noctalia.state.set("dmenu_active", false)
	noctalia.state.set("dmenu_items", {})
end

local function beginSession(config)
	sessionId = sessionId + 1
	noctalia.state.set("dmenu_sessionId", sessionId)
	noctalia.state.set("dmenu_items", config.items or {})
	noctalia.state.set("dmenu_prompt", config.prompt or "Search:")
	noctalia.state.set("dmenu_resultFile", config.resultFile or "/tmp/noctalia-dmenu-result")
	noctalia.state.set("dmenu_resultFormat", config.resultFormat or "plain")
	noctalia.state.set("dmenu_callbackCmd", config.callbackCmd or "")
	noctalia.state.set("dmenu_closeOnSelect", config.closeOnSelect ~= false)
	noctalia.state.set("dmenu_active", true)

	-- Open the launcher panel automatically
	noctalia.runAsync('noctalia msg panel-toggle launcher "/dmenu "')
end

function onIpc(event, arg1, arg2)
	if event == "showItems" then
		local items = arg1 or ""
		local opts = {}
		if arg2 and arg2 ~= "" then
			pcall(function()
				opts = noctalia.json.decode(arg2)
			end)
		end

		local parsedItems = parseItems(items, opts.separator)
		opts.items = parsedItems
		beginSession(opts)
	elseif event == "showJson" then
		local cfg = {}
		if arg1 and arg1 ~= "" then
			pcall(function()
				cfg = noctalia.json.decode(arg1)
			end)
		end
		if cfg.items then
			cfg.items = normalizeItems(cfg.items)
			beginSession(cfg)
		end
	elseif event == "showFromFile" then
		local path = arg1 or ""
		local opts = {}
		if arg2 and arg2 ~= "" then
			pcall(function()
				opts = noctalia.json.decode(arg2)
			end)
		end

		noctalia.runAsync(`cat '{path}' 2>/dev/null`, function(res)
			if res.exitCode == 0 and res.stdout ~= "" then
				local trimmed = res.stdout:gsub("^%s+", "")
				local first = trimmed:sub(1, 1)
				local parsed = {}
				if first == "[" then
					pcall(function()
						parsed = normalizeItems(noctalia.json.decode(res.stdout))
					end)
				elseif first == "{" then
					local config = {}
					pcall(function()
						config = noctalia.json.decode(res.stdout)
					end)
					parsed = normalizeItems(config.items or {})
					for k, v in pairs(config) do
						if k ~= "items" and opts[k] == nil then
							opts[k] = v
						end
					end
				else
					parsed = parseItems(res.stdout, opts.separator)
				end
				opts.items = parsed
				beginSession(opts)
			end
		end)
	elseif event == "select" then
		if type(arg1) == "table" then
			handleSelection(arg1.value, arg1.index)
		end
	elseif event == "close" or event == "clear" then
		noctalia.state.set("dmenu_active", false)
		noctalia.state.set("dmenu_items", {})
		noctalia.runAsync("noctalia msg panel-toggle launcher")
	end
end

noctalia.state.watch("command", function(cmd)
	if not cmd or type(cmd) ~= "table" then
		return
	end
	if cmd.action == "select" then
		handleSelection(cmd.value, cmd.index)
	end
end)
