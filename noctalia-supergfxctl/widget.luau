-- noctalia-supergfxctl — bar widget.

local currentMode = "unknown"
local pendingMode = ""
local supported = false

local MODE_ICONS = {
  Integrated = "cpu",
  Hybrid = "layers",
  NvidiaNoModeset = "gpu",
  Vfio = "server",
  AsusEgpu = "zap",
  AsusMuxDgpu = "gpu",
}

local function modeIcon(mode)
  return MODE_ICONS[mode] or "cpu"
end

local function render()
  if not supported then
    barWidget.setGlyph("cpu")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("supergfxctl not available")
    return
  end

  local icon = modeIcon(currentMode)
  barWidget.setGlyph(icon)

  if pendingMode ~= "" then
    barWidget.setGlyphColor("warning")
    barWidget.setText(currentMode)
    barWidget.setTooltip("GPU: " .. currentMode .. " → " .. pendingMode .. " (reboot required)")
  else
    if currentMode == "Hybrid" then
      barWidget.setGlyphColor("primary")
    elseif currentMode == "Integrated" then
      barWidget.setGlyphColor("on_surface_variant")
    else
      barWidget.setGlyphColor("on_surface")
    end
    barWidget.setText(currentMode)
    barWidget.setTooltip("GPU mode: " .. currentMode .. " — right-click to switch")
  end
end

function onClick()
  -- Cycle mode: Integrated -> Hybrid -> Integrated
  if currentMode == "Integrated" then
    noctalia.state.set("command", "setMode:Hybrid")
  elseif currentMode == "Hybrid" then
    noctalia.state.set("command", "setMode:Integrated")
  else
    noctalia.state.set("command", "setMode:Hybrid")
  end
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("currentMode", function(val)
  currentMode = val or "unknown"
  render()
end)

noctalia.state.watch("pendingMode", function(val)
  pendingMode = val or ""
  render()
end)

noctalia.state.watch("supported", function(val)
  supported = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
