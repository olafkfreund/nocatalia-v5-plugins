-- USB Drive Manager — bar widget.

local driveCount = 0
local mountedCount = 0

local function render()
  local hideWhenEmpty = barWidget.getConfig("hideWhenEmpty") == true
  local iconColor = barWidget.getConfig("iconColor") or "none"

  if driveCount == 0 and hideWhenEmpty then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)

  barWidget.setGlyph("usb")

  if iconColor ~= "none" and iconColor ~= "" then
    barWidget.setGlyphColor(iconColor)
  elseif mountedCount > 0 then
    barWidget.setGlyphColor("primary")
  else
    barWidget.setGlyphColor("on_surface_variant")
  end

  if driveCount > 0 then
    barWidget.setText(tostring(driveCount))
    local tooltip = driveCount .. " USB drive(s)"
    if mountedCount > 0 then
      tooltip = tooltip .. " | " .. mountedCount .. " mounted — right-click to unmount all"
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setText("")
    barWidget.setTooltip("No USB drives connected")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

function onRightClick()
  if mountedCount > 0 then
    noctalia.state.set("command", "unmountAll")
  else
    noctalia.state.set("command", "refresh")
  end
end

noctalia.state.watch("driveCount", function(val)
  driveCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("mountedCount", function(val)
  mountedCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
