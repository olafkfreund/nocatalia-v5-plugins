-- MangoWC Layout Switcher — bar widget.

local currentLayout = ""

local ICONS = {
  tiled = "layout-grid",
  monocle = "square",
  floating = "app-window",
}

local function render()
  local icon = ICONS[currentLayout] or "layout"
  barWidget.setGlyph(icon)
  barWidget.setGlyphColor("on_surface")
  barWidget.setText(currentLayout ~= "" and currentLayout or "")
  barWidget.setTooltip("MangoWC: " .. (currentLayout ~= "" and currentLayout or "Layout") .. " — click to cycle")
end

function onClick()
  noctalia.state.set("command", "cycle")
end

noctalia.state.watch("currentLayout", function(val)
  currentLayout = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
