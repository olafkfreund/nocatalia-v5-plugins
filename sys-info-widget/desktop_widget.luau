-- System Info — desktop widget.

local sysInfo = nil

local function getTempColor(tempString)
	if not tempString or tempString == "" then
		return "on_surface"
	end
	local valStr = tempString:match("%d+%.?%d*")
	if not valStr then
		return "on_surface"
	end
	local val = tonumber(valStr)
	if not val then
		return "on_surface"
	end
	if val >= 80 then
		return "error"
	elseif val >= 65 then
		return "warning"
	else
		return "success"
	end
end

local function render()
	local loadingText = noctalia.tr("widget.loading") or "Loading..."

	local distroVal = if sysInfo and sysInfo.distro then sysInfo.distro else loadingText
	local kernelVal = if sysInfo and sysInfo.kernel then sysInfo.kernel else loadingText
	local uptimeVal = if sysInfo and sysInfo.uptime then sysInfo.uptime else loadingText
	local cpuUsage = if sysInfo and sysInfo.cpuUsage then sysInfo.cpuUsage else loadingText
	local cpuTemp = if sysInfo and sysInfo.cpuTemp then sysInfo.cpuTemp else ""
	local memUsage = if sysInfo and sysInfo.memUsage then sysInfo.memUsage else loadingText
	local rootDisk = if sysInfo and sysInfo.rootDisk then sysInfo.rootDisk else loadingText
	local homeDisk = if sysInfo and sysInfo.homeDisk then sysInfo.homeDisk else loadingText
	local lanAddress = if sysInfo and sysInfo.lanAddress then sysInfo.lanAddress else loadingText
	local ipAddress = if sysInfo and sysInfo.ipAddress then sysInfo.ipAddress else loadingText

	local labelWidth = 120

	local cpuChildren = {
		ui.label({ text = cpuUsage, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
	}
	if cpuTemp ~= "" then
		table.insert(
			cpuChildren,
			ui.label({
				text = noctalia.tr("widget.separator_at") or "@",
				fontSize = 11,
				color = "on_surface_variant",
			})
		)
		table.insert(
			cpuChildren,
			ui.label({
				text = cpuTemp,
				fontSize = 11,
				color = getTempColor(cpuTemp),
				fontWeight = "medium",
			})
		)
	end

	local rows = {
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.distribution") or "System",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = distroVal, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.kernel") or "Kernel",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = kernelVal, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.uptime") or "Uptime",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = uptimeVal, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.cpu") or "CPU",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.row({ gap = 4, align = "center" }, cpuChildren),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.memory") or "Memory",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = memUsage, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.disk_root") or "Disk /",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = rootDisk, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.disk_home") or "Disk /home",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = homeDisk, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.divider({}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.lanaddress") or "Local IP",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = lanAddress, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
		ui.row({ gap = 12 }, {
			ui.label({
				text = noctalia.tr("widget.ipaddress") or "Public IP",
				fontSize = 11,
				color = "on_surface_variant",
				width = labelWidth,
			}),
			ui.label({ text = ipAddress, fontSize = 11, color = "on_surface", fontWeight = "medium" }),
		}),
	}

	desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
end

noctalia.state.watch("sysInfo", function(val)
	if type(val) == "table" then
		sysInfo = val
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(0)
	render()
end
