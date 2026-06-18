-- Update Count — bar widget.

local updateCount = 0
local refreshing = false

local function render()
  local iconName = barWidget.getConfig("currentIconName") or "world-download"
  barWidget.setGlyph(iconName)

  local hideOnZero = barWidget.getConfig("hideOnZero") == true

  if refreshing then
    barWidget.setGlyphColor("primary")
    barWidget.setText("...")
    barWidget.setTooltip("Checking for updates...")
    barWidget.setVisible(true)
    return
  end

  if updateCount <= 0 then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("tooltip.noUpdatesAvailable") or "System up to date")
    barWidget.setVisible(not hideOnZero)
    return
  end

  barWidget.setVisible(true)
  barWidget.setGlyphColor("warning")
  barWidget.setText(tostring(updateCount))
  barWidget.setTooltip(noctalia.tr("tooltip.updatesAvailable") or "Updates available")
end

function onClick()
  if updateCount > 0 then
    noctalia.state.set("command", "update")
  end
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("updateCount", function(val)
  updateCount = tonumber(val) or 0
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
