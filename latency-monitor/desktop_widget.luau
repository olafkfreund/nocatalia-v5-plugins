-- Latency Monitor — desktop widget.

local hosts = {}

local function render()
	local rows = {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({ text = "Latency Monitor", fontSize = 16, fontWeight = "bold", color = "primary" }),
		}),
	}

	if #hosts == 0 then
		table.insert(rows, ui.label({ text = "No data available yet...", fontSize = 13, color = "on_surface_variant" }))
	else
		for _, h in ipairs(hosts) do
			local color = "on_surface"
			if h.status == "good" then
				color = "success"
			elseif h.status == "warning" then
				color = "warning"
			elseif h.status == "critical" then
				color = "error"
			end

			local rttText = h.timedOut and "Timed out" or `{math.round(h.lastRtt)}ms`
			local avg10mText = h.avg10m >= 0 and `{math.round(h.avg10m)}ms` or "—"
			local avg30mText = h.avg30m >= 0 and `{math.round(h.avg30m)}ms` or "—"
			local avg60mText = h.avg60m >= 0 and `{math.round(h.avg60m)}ms` or "—"

			table.insert(
				rows,
				ui.column({ gap = 4, padding = 8 }, {
					ui.row({ gap = 12, align = "center" }, {
						ui.label({ text = h.name, fontSize = 13, fontWeight = "bold", color = color }),
						ui.label({ text = h.address, fontSize = 11, color = "on_surface_variant" }),
						ui.label({
							text = rttText,
							fontSize = 13,
							fontWeight = "semibold",
							color = color,
							align = "right",
						}),
					}),
					ui.row({ gap = 8 }, {
						ui.label({ text = `10m: {avg10mText}`, fontSize = 10, color = "on_surface_variant" }),
						ui.label({ text = `30m: {avg30mText}`, fontSize = 10, color = "on_surface_variant" }),
						ui.label({ text = `60m: {avg60mText}`, fontSize = 10, color = "on_surface_variant" }),
					}),
				})
			)
		end
	end

	desktopWidget.render(ui.column({ gap = 10, padding = 16 }, rows))
end

noctalia.state.watch("hosts", function(val)
	hosts = if type(val) == "table" then val else {}
	render()
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
