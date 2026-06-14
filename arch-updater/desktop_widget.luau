-- Arch Updater — desktop widget.

local updates = {}
local refreshing = false

local function render()
  if refreshing then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "Checking for updates...", fontSize = 14, color = "on_surface_variant" })
    }))
    return
  end

  local count = #updates
  if count == 0 then
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
      ui.label({ text = "System up to date", fontSize = 16, fontWeight = "semibold", color = "success" }),
      ui.button({ text = "Check Updates", variant = "outline", onClick = "refreshData" })
    }))
    return
  end

  local rows = {
    ui.label({ text = `{count} Updates Available`, fontSize = 18, fontWeight = "bold", color = "warning" })
  }

  local sysCount, aurCount, flatCount = 0, 0, 0
  for _, item in updates do
    if item.source == "system" then sysCount += 1
    elseif item.source == "aur" then aurCount += 1
    elseif item.source == "flatpak" then flatCount += 1
    end
  end

  if sysCount > 0 then
    table.insert(rows, ui.label({ text = `System: {sysCount}`, fontSize = 14, color = "on_surface" }))
  end
  if aurCount > 0 then
    table.insert(rows, ui.label({ text = `AUR: {aurCount}`, fontSize = 14, color = "on_surface" }))
  end
  if flatCount > 0 then
    table.insert(rows, ui.label({ text = `Flatpak: {flatCount}`, fontSize = 14, color = "on_surface" }))
  end

  table.insert(rows, ui.row({ gap = 8 }, {
    ui.button({ text = "Update Now", variant = "primary", onClick = "runUpdate" }),
    ui.button({ text = "Check Again", variant = "outline", onClick = "refreshData" })
  }))

  desktopWidget.render(ui.column({ gap = 8, align = "center" }, rows))
end

function refreshData()
  noctalia.state.set("command", "refresh")
end

function runUpdate()
  noctalia.state.set("command", "update")
end

noctalia.state.watch("updates", function(val)
  updates = if type(val) == "table" then val else {}
  render()
end)

noctalia.state.watch("refreshing", function(val)
  refreshing = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
