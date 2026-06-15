-- Special Workspaces — desktop widget.

local activeSpecialByMonitor = {}
local activeWorkspaceNames = {}
local clickFuncs = {}

local function render()
	-- Clean up old global functions
	for name, _ in pairs(clickFuncs) do
		_G[name] = nil
	end
	clickFuncs = {}

	local function regClick(name, fn)
		_G[name] = fn
		clickFuncs[name] = true
	end

	local workspacesStr = noctalia.getConfig("workspaces")
		or '[{"name":"communication"},{"name":"music"},{"name":"agent"}]'
	local ok, workspacesList = pcall(function()
		return noctalia.json.decode(workspacesStr)
	end)
	if not ok or type(workspacesList) ~= "table" then
		workspacesList = {}
	end

	local hideEmpty = noctalia.getConfig("hideEmptyWorkspaces") == true

	local rows = {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({
				text = "Special Workspaces",
				fontSize = 16,
				fontWeight = "bold",
				color = "primary",
			}),
		}),
	}

	for _, ws in ipairs(workspacesList) do
		local wsFullName = "special:" .. ws.name
		local isActive = activeWorkspaceNames[wsFullName] == true

		local isFocused = false
		for _, focusedWs in pairs(activeSpecialByMonitor) do
			if focusedWs == wsFullName then
				isFocused = true
				break
			end
		end

		if not (hideEmpty and not isActive and not isFocused) then
			local displayName = ws.name:sub(1, 1):upper() .. ws.name:sub(2)
			local statusText = ""
			if isFocused then
				statusText = "● Focused"
			elseif isActive then
				statusText = "○ Active"
			else
				statusText = "Inactive"
			end

			local actionName = `toggle_{ws.name:gsub("[^%w]", "_")}`
			regClick(actionName, function()
				noctalia.state.set("command", { action = "toggle", workspace = wsFullName })
			end)

			table.insert(
				rows,
				ui.row({ gap = 12, align = "center" }, {
					ui.label({
						text = displayName,
						fontSize = 14,
						fontWeight = "semibold",
						color = isFocused and "primary" or "on_surface",
					}),
					ui.label({
						text = statusText,
						fontSize = 11,
						color = isFocused and "primary" or "on_surface_variant",
						fillWidth = true,
					}),
					ui.button({
						text = isFocused and "Hide" or "Show",
						variant = isFocused and "primary" or "outline",
						onClick = actionName,
					}),
				})
			)
		end
	end

	desktopWidget.render(ui.column({ gap = 10, padding = 16 }, rows))
end

noctalia.state.watch("activeSpecialByMonitor", function(val)
	activeSpecialByMonitor = if type(val) == "table" then val else {}
	render()
end)

noctalia.state.watch("activeWorkspaceNames", function(val)
	activeWorkspaceNames = if type(val) == "table" then val else {}
	render()
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
