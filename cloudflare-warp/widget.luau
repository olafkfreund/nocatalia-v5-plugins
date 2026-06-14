-- Cloudflare WARP — bar widget.

local installed = false
local connected = false
local mode = ""

local function render()
  if not installed then
    barWidget.setGlyph("cloud-off")
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip(noctalia.tr("panel.not-installed"))
    return
  end

  local icon = if connected then "cloud-lock" else "cloud"
  barWidget.setGlyph(icon)

  local colorKey = if connected then (barWidget.getConfig("connectedColor") or "primary") else (barWidget.getConfig("disconnectedColor") or "on_surface_variant")
  barWidget.setGlyphColor(colorKey)

  local statusText = if connected then noctalia.tr("panel.status.connected") else noctalia.tr("panel.status.disconnected")
  local tooltip = `Cloudflare WARP\nStatus: {statusText}`
  if mode ~= "" then
    tooltip ..= `\nMode: {mode}`
  end
  tooltip ..= "\n\nLeft-click: Toggle Connection\nRight-click: Refresh"
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.state.set("command", "toggle")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("installed", function(val)
  installed = val == true
  render()
end)

noctalia.state.watch("connected", function(val)
  connected = val == true
  render()
end)

noctalia.state.watch("mode", function(val)
  mode = if type(val) == "string" then val else ""
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
