-- DNS Switcher — bar widget.

local activeProviderId = "default"
local currentDnsName = "Default (ISP)"

local providerIcons = {
	google = "brand-google",
	cloudflare = "cloud",
	opendns = "world",
	adguard = "shield-check",
	quad9 = "lock",
}

local function render()
	local glyph = providerIcons[activeProviderId] or "globe"
	barWidget.setGlyph(glyph)
	barWidget.setGlyphColor("primary")
	barWidget.setText(currentDnsName)

	local tooltip = `DNS Status\nProvider: {currentDnsName}\nClick to toggle desktop widget`
	barWidget.setTooltip(tooltip)
end

function onClick()
	noctalia.runAsync("noctalia msg desktop-widgets-toggle-edit")
end

noctalia.state.watch("activeProviderId", function(val)
	if type(val) == "string" then
		activeProviderId = val
		render()
	end
end)

noctalia.state.watch("currentDnsName", function(val)
	if type(val) == "string" then
		currentDnsName = val
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
