-- Privacy Indicator — bar widget.

local cameraApps = ""
local micApps = ""
local cameraActive = false
local micActive = false

local function render()
  local hideInactive = barWidget.getConfig("hideInactive") == true
  local activeColor = barWidget.getConfig("activeColor") or "primary"
  local inactiveColor = barWidget.getConfig("inactiveColor") or "on_surface_variant"

  if not cameraActive and not micActive then
    if hideInactive then
      barWidget.setVisible(false)
      return
    end
    barWidget.setVisible(true)
    barWidget.setGlyph("shield-check")
    if inactiveColor == "none" then
      barWidget.setGlyphColor("on_surface_variant")
    else
      barWidget.setGlyphColor(inactiveColor)
    end
    barWidget.setText("")
    barWidget.setTooltip("Privacy: Camera and mic are not in use")
    return
  end

  barWidget.setVisible(true)

  local glyphs = {}
  local tooltip = "Privacy alert:"

  if cameraActive then
    glyphs[#glyphs + 1] = "camera"
    tooltip = tooltip .. " camera (" .. cameraApps .. ")"
  end
  if micActive then
    glyphs[#glyphs + 1] = "mic"
    if cameraActive then tooltip = tooltip .. "," end
    tooltip = tooltip .. " mic (" .. micApps .. ")"
  end

  barWidget.setGlyph(glyphs[1] or "shield-check")
  barWidget.setGlyphColor(activeColor)
  barWidget.setText("")
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("cameraActive", function(val)
  cameraActive = val == true
  render()
end)

noctalia.state.watch("micActive", function(val)
  micActive = val == true
  render()
end)

noctalia.state.watch("cameraApps", function(val)
  cameraApps = val or ""
  render()
end)

noctalia.state.watch("micApps", function(val)
  micApps = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
