-- Special Workspaces — bar widget.

local activeSpecialByMonitor = {}
local activeWorkspaceNames = {}

local function render()
	local icon = barWidget.getConfig("mainIcon") or "layout-grid"
	barWidget.setGlyph(icon)

	-- Find if there is any active special workspace focused on any monitor
	local focusedWs = nil
	for _, ws in pairs(activeSpecialByMonitor) do
		if ws and ws ~= "" then
			focusedWs = ws
			break
		end
	end

	if focusedWs then
		barWidget.setGlyphColor("primary")
		local shortName = focusedWs
		if shortName:sub(1, 8) == "special:" then
			shortName = shortName:sub(9)
		end
		barWidget.setText(shortName)
		barWidget.setTooltip(`Special Workspace Focused: {shortName}\nClick to toggle workspace off`)
	else
		barWidget.setGlyphColor("on_surface_variant")
		barWidget.setText("")
		barWidget.setTooltip("Special Workspaces (Hyprland)\nClick to toggle desktop control panel")
	end
end

function onClick()
	-- If a special workspace is focused, toggle it off
	local focusedWs = nil
	for _, ws in pairs(activeSpecialByMonitor) do
		if ws and ws ~= "" then
			focusedWs = ws
			break
		end
	end

	if focusedWs then
		noctalia.state.set("command", { action = "toggle_active" })
	else
		noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
	end
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
