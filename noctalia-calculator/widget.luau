-- Noctalia Calculator — bar widget.

local currentValue = "0"
local hasError = false

local function render()
  barWidget.setGlyph("calculator")

  if hasError then
    barWidget.setGlyphColor("error")
    barWidget.setText("Err")
    barWidget.setTooltip("Calculator: Error in expression")
  elseif currentValue ~= "0" and currentValue ~= "" then
    barWidget.setGlyphColor("primary")
    local showValue = barWidget.getConfig("showBarValue") ~= false
    if showValue then
      barWidget.setText(currentValue)
    else
      barWidget.setText("")
    end
    barWidget.setTooltip("Calculator: " .. currentValue)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Calculator — click to open")
  end
end

function onClick()
  noctalia.state.set("command", "clear")
end

noctalia.state.watch("currentValue", function(val)
  currentValue = val or "0"
  render()
end)

noctalia.state.watch("hasError", function(val)
  hasError = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
