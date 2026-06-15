-- Latency Monitor — bar widget.

local worstHost = nil

local function render()
	if not worstHost then
		barWidget.setGlyph("cloud")
		barWidget.setGlyphColor("on_surface_variant")
		barWidget.setText("...")
		barWidget.setTooltip("Latency Monitor\nNo data yet")
		return
	end

	local color = "on_surface"
	if worstHost.status == "good" then
		color = "success"
	elseif worstHost.status == "warning" then
		color = "warning"
	elseif worstHost.status == "critical" then
		color = "error"
	end

	local displayRtt = worstHost.timedOut and "✕"
		or `{math.round(worstHost.avg10m >= 0 and worstHost.avg10m or worstHost.lastRtt)}ms`

	barWidget.setGlyph("cloud")
	barWidget.setGlyphColor(color)
	barWidget.setText(`{worstHost.name} {displayRtt}`)

	local tooltip =
		`Latency Monitor\nWorst host: {worstHost.name}\nIP: {worstHost.address}\nLatency: {displayRtt}\nClick to toggle desktop widget`
	barWidget.setTooltip(tooltip)
end

function onClick()
	noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("worstHost", function(val)
	worstHost = if type(val) == "table" then val else nil
	render()
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
