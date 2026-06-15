-- Display Settings — desktop widget.

local outputs = {}
local compositor = "unknown"
local clickFuncs = {}

function triggerRefresh()
	noctalia.state.set("command", { action = "refresh" })
end

local function render()
	-- Clean up old global functions
	for name, _ in pairs(clickFuncs) do
		_G[name] = nil
	end
	clickFuncs = {}

	local isNiri = compositor == "niri"

	local rows = {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({ text = "Display Settings", fontSize = 16, fontWeight = "bold", color = "primary" }),
			ui.button({ text = "↻", variant = "flat", onClick = "triggerRefresh" }),
		}),
	}

	if not isNiri then
		table.insert(
			rows,
			ui.label({
				text = "Read-only mode (wlr-randr). Controls are only supported on Niri compositor.",
				fontSize = 11,
				color = "on_surface_variant",
			})
		)
	end

	local function regClick(name, fn)
		_G[name] = fn
		clickFuncs[name] = true
	end

	if #outputs == 0 then
		table.insert(rows, ui.label({ text = "No outputs detected", fontSize = 13, color = "on_surface_variant" }))
	else
		for idx, out in ipairs(outputs) do
			local nameId = out.name:gsub("[^%w]", "_")
			local infoRows = {
				ui.row({ gap = 8, align = "center" }, {
					ui.label({ text = out.name, fontSize = 14, fontWeight = "bold", color = "primary" }),
					ui.label({ text = out.model, fontSize = 11, color = "on_surface_variant", fillWidth = true }),
					ui.label({ text = out.current_mode, fontSize = 12, color = "on_surface" }),
				}),
			}

			if isNiri then
				-- Scale controls
				local nextScale = 1.0
				if out.scale == 1.0 then
					nextScale = 1.25
				elseif out.scale == 1.25 then
					nextScale = 1.5
				elseif out.scale == 1.5 then
					nextScale = 2.0
				else
					nextScale = 1.0
				end

				local scaleAction = `cycle_scale_{nameId}`
				regClick(scaleAction, function()
					noctalia.state.set("command", { action = "scale", output = out.name, value = nextScale })
				end)

				-- Transform controls
				local nextTrans = "Normal"
				if out.transform == "Normal" then
					nextTrans = "90"
				elseif out.transform == "90" then
					nextTrans = "180"
				elseif out.transform == "180" then
					nextTrans = "270"
				else
					nextTrans = "Normal"
				end

				local transAction = `cycle_trans_{nameId}`
				regClick(transAction, function()
					noctalia.state.set("command", { action = "transform", output = out.name, value = nextTrans })
				end)

				-- Power toggle
				local powerAction = `toggle_power_{nameId}`
				regClick(powerAction, function()
					noctalia.state.set("command", { action = "power", output = out.name, value = not out.enabled })
				end)

				local btnRow = {
					ui.button({
						text = `Scale: {out.scale}x`,
						variant = "outline",
						onClick = scaleAction,
						disabled = not out.enabled,
					}),
					ui.button({
						text = `Rotate: {out.transform}`,
						variant = "outline",
						onClick = transAction,
						disabled = not out.enabled,
					}),
				}

				-- VRR toggle
				if out.vrr_supported then
					local vrrAction = `toggle_vrr_{nameId}`
					regClick(vrrAction, function()
						noctalia.state.set(
							"command",
							{ action = "vrr", output = out.name, value = not out.vrr_enabled }
						)
					end)
					table.insert(
						btnRow,
						ui.button({
							text = out.vrr_enabled and "VRR: On" or "VRR: Off",
							variant = out.vrr_enabled and "primary" or "outline",
							onClick = vrrAction,
							disabled = not out.enabled,
						})
					)
				end

				table.insert(
					btnRow,
					ui.button({
						text = out.enabled and "Turn Off" or "Turn On",
						variant = out.enabled and "flat" or "primary",
						onClick = powerAction,
					})
				)

				table.insert(infoRows, ui.row({ gap = 8 }, btnRow))
			else
				table.insert(
					infoRows,
					ui.row({ gap = 12 }, {
						ui.label({ text = `Scale: {out.scale}x`, fontSize = 11, color = "on_surface_variant" }),
						ui.label({ text = `Rotation: {out.transform}`, fontSize = 11, color = "on_surface_variant" }),
						ui.label({
							text = out.vrr_enabled and "VRR: Enabled" or "VRR: Disabled",
							fontSize = 11,
							color = "on_surface_variant",
						}),
					})
				)
			end

			table.insert(rows, ui.column({ gap = 4, padding = 8 }, infoRows))
		end
	end

	desktopWidget.render(ui.column({ gap = 10, padding = 16 }, rows))
end

noctalia.state.watch("outputs", function(val)
	outputs = if type(val) == "table" then val else {}
	render()
end)

noctalia.state.watch("compositor", function(val)
	if type(val) == "string" then
		compositor = val
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
