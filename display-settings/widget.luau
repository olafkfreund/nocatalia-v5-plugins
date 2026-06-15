-- Display Settings — bar widget.

local outputsCount = 0

local function render()
	local colorKey = barWidget.getConfig("iconColor") or "primary"
	barWidget.setGlyph("device-monitor")
	barWidget.setGlyphColor(colorKey)
	barWidget.setText(outputsCount > 0 and tostring(outputsCount) or "")
	barWidget.setTooltip(`Display Settings\nConnected displays: {outputsCount}\nClick to toggle desktop widget`)
end

function onClick()
	noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("outputs", function(val)
	if type(val) == "table" then
		outputsCount = #val
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
