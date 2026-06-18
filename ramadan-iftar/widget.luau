-- Ramadan Iftar — bar widget.

local iftarTime = ""
local suhoorTime = ""
local isRamadan = false
local configured = false

local function render()
  local showAlways = barWidget.getConfig("showAlways") == true

  barWidget.setGlyph("moon")

  if not configured then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Ramadan Iftar: Set city and country in settings")
    return
  end

  if not isRamadan and not showAlways then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)

  if iftarTime ~= "" then
    barWidget.setGlyphColor("primary")
    barWidget.setText("Iftar " .. iftarTime)
    local tooltip = "Iftar: " .. iftarTime
    if suhoorTime ~= "" then
      tooltip = tooltip .. " | Suhoor: " .. suhoorTime
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Fetching prayer times...")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("iftarTime", function(val)
  iftarTime = val or ""
  render()
end)

noctalia.state.watch("suhoorTime", function(val)
  suhoorTime = val or ""
  render()
end)

noctalia.state.watch("isRamadan", function(val)
  isRamadan = val == true
  render()
end)

noctalia.state.watch("configured", function(val)
  configured = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
