-- Steam Price Watcher — bar widget.

local dealsCount = 0
local dealsSummary = ""

local function render()
  barWidget.setGlyph("gamepad")

  if dealsCount > 0 then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(dealsCount))
    barWidget.setTooltip("Steam deals: " .. dealsSummary)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Steam Price Watcher: No deals on watchlist")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("dealsCount", function(val)
  dealsCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("dealsSummary", function(val)
  dealsSummary = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
