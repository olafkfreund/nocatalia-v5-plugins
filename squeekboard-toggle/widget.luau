-- Squeekboard Toggle — bar widget.

local available = false
local keyboardActive = false
local gsettingsOk = true

local function render()
  local hideWhenUnavailable = barWidget.getConfig("hideWhenUnavailable") == true

  if not available then
    barWidget.setVisible(not hideWhenUnavailable)
    barWidget.setGlyph("alert-circle")
    barWidget.setGlyphColor("error")
    if not gsettingsOk then
      barWidget.setTooltip(noctalia.tr("tooltip.noGsettings") or "gsettings not available")
    else
      barWidget.setTooltip(noctalia.tr("tooltip.noSqueekboard") or "Squeekboard not running")
    end
    barWidget.setText("")
    return
  end

  barWidget.setVisible(true)
  barWidget.setText("")

  if keyboardActive then
    barWidget.setGlyph("keyboard")
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip(noctalia.tr("tooltip.active") or "Keyboard active — click to hide")
  else
    barWidget.setGlyph("keyboard-off")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip(noctalia.tr("tooltip.hidden") or "Keyboard hidden — click to show")
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("available", function(val)
  available = val == true
  render()
end)

noctalia.state.watch("keyboardActive", function(val)
  keyboardActive = val == true
  render()
end)

noctalia.state.watch("gsettingsOk", function(val)
  gsettingsOk = val ~= false
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
