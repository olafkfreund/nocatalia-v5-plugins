-- widget.luau: Port Monitor bar widget
-- Reads portCount from service state and updates bar display

local hideWhenEmpty = noctalia.settings.get("hideWhenEmpty") or false

-- Refresh settings on each update cycle
local function reloadSettings()
	hideWhenEmpty = noctalia.settings.get("hideWhenEmpty") or false
end

-- Apply current portCount to the bar widget visuals
local function applyState(portCount)
	reloadSettings()

	if portCount == 0 and hideWhenEmpty then
		barWidget.setVisible(false)
		return
	end

	barWidget.setVisible(true)
	barWidget.setGlyph("network")
	barWidget.setText(tostring(portCount))
	barWidget.setTooltip(tostring(portCount) .. " listening ports")

	if portCount > 0 then
		barWidget.setGlyphColor("on_surface")
	else
		barWidget.setGlyphColor("on_surface")
	end
end

-- Watch service state for portCount changes
noctalia.state.watch("portCount", function(val)
	local count = tonumber(val) or 0
	applyState(count)
end)

-- update() is called once on widget init and periodically by the runtime
function update()
	reloadSettings()
	local count = tonumber(noctalia.state.get("portCount")) or 0
	applyState(count)
end
