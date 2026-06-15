-- DNS Switcher — desktop widget.

local activeProviderId = "default"
local currentDnsName = "Default (ISP)"
local isChanging = false
local lastError = ""
local customProviders = {}
local clickFuncs = {}

local defaultProviders = {
	{ id = "google", label = "Google", ip = "8.8.8.8 8.8.4.4" },
	{ id = "cloudflare", label = "Cloudflare", ip = "1.1.1.1 1.0.0.1" },
	{ id = "opendns", label = "OpenDNS", ip = "208.67.222.222 208.67.220.220" },
	{ id = "adguard", label = "AdGuard", ip = "94.140.14.14 94.140.15.15" },
	{ id = "quad9", label = "Quad9", ip = "9.9.9.9 149.112.112.112" },
}

local function promptCustomServer(callback)
	local nameCmd =
		"zenity --entry --title='Add DNS Server' --text='Enter server name:' 2>/dev/null || kdialog --inputbox 'Enter server name:' 2>/dev/null"
	noctalia.runAsync(nameCmd, function(nameRes)
		if nameRes.exitCode ~= 0 then
			return
		end
		local name = (nameRes.stdout or ""):gsub("[\r\n]+$", "")
		if name == "" then
			return
		end

		local ipCmd =
			"zenity --entry --title='Add DNS Server' --text='Enter IP address(es) (e.g. 1.2.3.4):' 2>/dev/null || kdialog --inputbox 'Enter IP address(es):' 2>/dev/null"
		noctalia.runAsync(ipCmd, function(ipRes)
			if ipRes.exitCode ~= 0 then
				return
			end
			local ip = (ipRes.stdout or ""):gsub("[\r\n]+$", "")
			if ip == "" then
				return
			end

			callback(name, ip)
		end)
	end)
end

local function render()
	-- Clean up old global functions
	for name, _ in pairs(clickFuncs) do
		_G[name] = nil
	end
	clickFuncs = {}

	local rows = {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({ text = "DNS Switcher", fontSize = 16, fontWeight = "bold", color = "primary" }),
			ui.label({
				text = isChanging and "Switching..." or currentDnsName,
				fontSize = 12,
				color = "on_surface_variant",
			}),
		}),
	}

	if lastError ~= "" then
		table.insert(rows, ui.label({ text = lastError, fontSize = 12, color = "error", fontWeight = "bold" }))
	end

	-- Helper to register dynamic click
	local function regClick(name, fn)
		_G[name] = fn
		clickFuncs[name] = true
	end

	-- Preset options
	for _, prov in ipairs(defaultProviders) do
		local actionName = `set_dns_{prov.id}`
		regClick(actionName, function()
			noctalia.state.set("command", prov.id)
		end)

		local isSelected = activeProviderId == prov.id
		table.insert(
			rows,
			ui.row({ gap = 12, align = "center" }, {
				ui.label({
					text = isSelected and "●" or "○",
					fontSize = 12,
					color = isSelected and "primary" or "on_surface_variant",
				}),
				ui.button({
					text = prov.label,
					variant = isSelected and "primary" or "outline",
					onClick = actionName,
					disabled = isChanging,
				}),
				ui.label({ text = prov.ip, fontSize = 11, color = "on_surface_variant" }),
			})
		)
	end

	-- Custom options
	for idx, prov in ipairs(customProviders) do
		local providerId = "custom_" .. tostring(idx)
		local actionName = `set_dns_{providerId}`
		regClick(actionName, function()
			noctalia.state.set("command", { action = "set", ip = prov.ip })
		end)

		local removeName = `remove_dns_{providerId}`
		regClick(removeName, function()
			noctalia.state.set("command", { action = "remove", index = idx })
		end)

		local isSelected = activeProviderId == providerId
		table.insert(
			rows,
			ui.row({ gap = 12, align = "center" }, {
				ui.label({
					text = isSelected and "●" or "○",
					fontSize = 12,
					color = isSelected and "primary" or "on_surface_variant",
				}),
				ui.button({
					text = prov.label,
					variant = isSelected and "primary" or "outline",
					onClick = actionName,
					disabled = isChanging,
				}),
				ui.label({ text = prov.ip, fontSize = 11, color = "on_surface_variant", fillWidth = true }),
				ui.button({
					text = "✕",
					variant = "flat",
					onClick = removeName,
					disabled = isChanging,
				}),
			})
		)
	end

	-- Add server button
	regClick("add_custom", function()
		promptCustomServer(function(name, ip)
			noctalia.state.set("command", { action = "add", label = name, ip = ip })
		end)
	end)

	-- Reset button
	regClick("reset_default", function()
		noctalia.state.set("command", "default")
	end)

	table.insert(
		rows,
		ui.row({ gap = 8 }, {
			ui.button({ text = "+ Add Custom Server", variant = "outline", onClick = "add_custom" }),
			ui.button({ text = "Reset to Default", variant = "flat", onClick = "reset_default" }),
		})
	)

	desktopWidget.render(ui.column({ gap = 10, padding = 16 }, rows))
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

noctalia.state.watch("isChanging", function(val)
	isChanging = val == true
	render()
end)

noctalia.state.watch("lastError", function(val)
	if type(val) == "string" then
		lastError = val
		render()
	end
end)

noctalia.state.watch("customProviders", function(val)
	customProviders = if type(val) == "table" then val else {}
	render()
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
