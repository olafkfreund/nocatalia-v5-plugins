-- Habitica — bar widget.

local dueDailies = 0
local dueTodos = 0
local configured = false
local hp = 0

local function render()
  barWidget.setGlyph("check-square")

  if not configured then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Habitica: Configure user ID and API token in settings")
    return
  end

  local total = dueDailies + dueTodos
  if total > 0 then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(total))
    local tooltip = ""
    if dueDailies > 0 then
      tooltip = dueDailies .. " due dailies"
    end
    if dueTodos > 0 then
      if tooltip ~= "" then tooltip = tooltip .. " | " end
      tooltip = tooltip .. dueTodos .. " open todos"
    end
    if hp < 30 then
      tooltip = tooltip .. " | HP: " .. math.floor(hp)
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyphColor("success")
    barWidget.setText("")
    barWidget.setTooltip("Habitica: All tasks done!")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("dueDailies", function(val)
  dueDailies = tonumber(val) or 0
  render()
end)

noctalia.state.watch("dueTodos", function(val)
  dueTodos = tonumber(val) or 0
  render()
end)

noctalia.state.watch("configured", function(val)
  configured = val == true
  render()
end)

noctalia.state.watch("hp", function(val)
  hp = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
