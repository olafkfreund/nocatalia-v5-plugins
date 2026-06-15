-- IP Monitor — bar widget.

local currentIp = "n/a"
local fetchState = "idle"

local function render()
	local successIcon = barWidget.getConfig("successIcon") or "network"
	local errorIcon = barWidget.getConfig("errorIcon") or "alert-circle"
	local loadingIcon = barWidget.getConfig("loadingIcon") or "loader"
	local iconColorKey = barWidget.getConfig("iconColor") or "primary"

	local glyph = successIcon
	local color = iconColorKey

	if fetchState == "loading" then
		glyph = loadingIcon
		color = "on_surface_variant"
	elseif fetchState == "error" then
		glyph = errorIcon
		color = "error"
	end

	barWidget.setGlyph(glyph)
	barWidget.setGlyphColor(color)
	barWidget.setText(currentIp)

	local tooltip = `IP Monitor\nIP: {currentIp}\nClick to toggle desktop widget`
	barWidget.setTooltip(tooltip)
end

function onClick()
	noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("currentIp", function(val)
	if type(val) == "string" then
		currentIp = val
		render()
	end
end)

noctalia.state.watch("fetchState", function(val)
	if type(val) == "string" then
		fetchState = val
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
