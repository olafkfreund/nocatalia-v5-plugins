-- Arch Updater — bar widget.

local updateCount = 0
local refreshing = false
local noctaliaUpdate = false
local updates = {}

local function render()
  local iconName = barWidget.getConfig("iconName") or "arrow-big-down-lines"
  barWidget.setGlyph(iconName)

  local hideOnEmpty = barWidget.getConfig("hideOnEmpty") == true

  if refreshing then
    barWidget.setGlyphColor("primary")
    barWidget.setText("...")
    barWidget.setTooltip("Checking for updates...")
    barWidget.setVisible(true)
    return
  end

  if updateCount == 0 then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("System up to date")
    barWidget.setVisible(not hideOnEmpty)
    return
  end

  barWidget.setVisible(true)

  if noctaliaUpdate then
    barWidget.setGlyphColor("warning")
    barWidget.setText(`{updateCount}!`)
  else
    local enableColorization = barWidget.getConfig("enableColorization") == true
    if enableColorization then
      barWidget.setGlyphColor("error")
    else
      barWidget.setGlyphColor("on_surface")
    end
    barWidget.setText(tostring(updateCount))
  end

  local tooltip = `Arch Updater — {updateCount} update(s) available\n`
  local sysCount, aurCount, flatCount = 0, 0, 0
  for _, item in updates do
    if item.source == "system" then sysCount += 1
    elseif item.source == "aur" then aurCount += 1
    elseif item.source == "flatpak" then flatCount += 1
    end
  end

  if sysCount > 0 then tooltip ..= `• System: {sysCount}\n` end
  if aurCount > 0 then tooltip ..= `• AUR: {aurCount}\n` end
  if flatCount > 0 then tooltip ..= `• Flatpak: {flatCount}\n` end
  if noctaliaUpdate then tooltip ..= "\n⚠️ Noctalia updates available!\n" end

  tooltip ..= "\nLeft-click: Launch updater\nRight-click: Refresh"
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.state.set("command", "update")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("updates", function(val)
  updates = if type(val) == "table" then val else {}
  updateCount = #updates
  render()
end)

noctalia.state.watch("refreshing", function(val)
  refreshing = val == true
  render()
end)

noctalia.state.watch("noctalia_update", function(val)
  noctaliaUpdate = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
