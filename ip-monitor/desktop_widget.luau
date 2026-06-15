-- IP Monitor — desktop widget.

local currentIp = "n/a"
local fetchState = "idle"
local ipData = nil
local clickFuncs = {}

function triggerRefresh()
	noctalia.state.set("command", "refresh")
end

function copyIp()
	if currentIp ~= "n/a" and currentIp ~= "" then
		noctalia.runAsync(`printf '%s' '{currentIp}' | wl-copy`, function(res)
			noctalia.notify("IP Monitor", "IP copied to clipboard!")
		end)
	end
end

local function render()
	-- Clean up old global functions
	for name, _ in pairs(clickFuncs) do
		_G[name] = nil
	end
	clickFuncs = {}

	local title = noctalia.tr("panel.title") or "IP Information"

	local rows = {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = "primary" }),
			ui.button({
				text = "↻",
				variant = "flat",
				onClick = "triggerRefresh",
				disabled = fetchState == "loading",
			}),
		}),
	}

	if fetchState == "loading" then
		table.insert(rows, ui.label({ text = "Fetching IP...", fontSize = 14, color = "on_surface_variant" }))
	elseif fetchState == "error" then
		table.insert(
			rows,
			ui.label({ text = "Failed to fetch IP", fontSize = 14, color = "error", fontWeight = "bold" })
		)
	elseif fetchState == "success" and ipData then
		table.insert(
			rows,
			ui.row({ gap = 8, align = "center" }, {
				ui.label({ text = currentIp, fontSize = 20, fontWeight = "bold", color = "primary" }),
				ui.button({ text = "📋 Copy", variant = "outline", onClick = "copyIp" }),
			})
		)

		local details = {
			{ label = "City", value = ipData.city },
			{ label = "Country", value = ipData.country },
			{ label = "Region", value = ipData.region },
			{ label = "Continent", value = ipData.continent },
			{ label = "Postal Code", value = ipData.postal },
			{ label = "Location", value = ipData.loc },
			{ label = "Timezone", value = ipData.timezone },
			{ label = "Currency", value = ipData.currency },
			{ label = "Organization", value = ipData.org },
			{ label = "AS Name", value = ipData["as"] },
		}

		for _, detail in ipairs(details) do
			if detail.value and detail.value ~= "n/a" then
				table.insert(
					rows,
					ui.row({ gap = 12 }, {
						ui.label({
							text = detail.label .. ":",
							fontSize = 11,
							color = "on_surface_variant",
							width = 80,
						}),
						ui.label({ text = detail.value, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
					})
				)
			end
		end
	end

	desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
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

noctalia.state.watch("ipData", function(val)
	ipData = if type(val) == "table" then val else nil
	render()
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
