-- Keep Awake Plus — bar widget.

local isActive = false
local statusText = ""

local function render()
  barWidget.setGlyph("sun")

  if isActive then
    barWidget.setGlyphColor("warning")
    local showText = barWidget.getConfig("showRemainingText") ~= false
    if showText and statusText ~= "" then
      barWidget.setText(statusText)
    else
      barWidget.setText("")
    end
    barWidget.setTooltip("Keep Awake: Active" .. (statusText ~= "" and " (" .. statusText .. " remaining)" or ""))
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Keep Awake: Inactive — click to activate")
  end
end

function onClick()
  noctalia.state.set("command", "toggle")
end

function onRightClick()
  noctalia.state.set("command", "deactivate")
end

noctalia.state.watch("isActive", function(val)
  isActive = val == true
  render()
end)

noctalia.state.watch("statusText", function(val)
  statusText = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
