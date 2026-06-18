-- kubectl-ctx — bar widget.

local currentContext = ""
local available = false
local errorMsg = ""

local function render()
  local iconColor = barWidget.getConfig("iconColor") or "none"
  local showError = barWidget.getConfig("showErrorBadge") ~= false

  barWidget.setGlyph("server")

  if not available then
    if showError then
      barWidget.setGlyphColor("error")
      barWidget.setText("")
      barWidget.setTooltip("kubectl not available: " .. errorMsg)
    else
      barWidget.setGlyphColor("on_surface_variant")
      barWidget.setText("")
      barWidget.setTooltip("kubectl not configured")
    end
    return
  end

  if iconColor ~= "none" and iconColor ~= "" then
    barWidget.setGlyphColor(iconColor)
  else
    barWidget.setGlyphColor("on_surface")
  end

  local display = currentContext
  if #display > 20 then
    display = display:sub(1, 17) .. "..."
  end
  barWidget.setText(display)
  barWidget.setTooltip("Kubernetes context: " .. currentContext .. "\nLeft-click to refresh")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("currentContext", function(val)
  currentContext = val or ""
  render()
end)

noctalia.state.watch("available", function(val)
  available = val == true
  render()
end)

noctalia.state.watch("errorMsg", function(val)
  errorMsg = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
