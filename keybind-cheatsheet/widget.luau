-- Keybind Cheatsheet — bar widget.

local bindsCount = 0
local compositor = ""

local function render()
  barWidget.setGlyph("keyboard")
  
  local tooltip = "Keybind Cheatsheet\n"
  if compositor ~= "" then
    tooltip ..= `Detected compositor: {compositor}\n`
  end
  if bindsCount > 0 then
    tooltip ..= `{bindsCount} shortcuts loaded\n`
  end
  tooltip ..= "Click to open launcher search"
  barWidget.setTooltip(tooltip)
end

function onClick()
  -- Toggle launcher
  noctalia.runAsync("noctalia msg panel-toggle launcher \"/keys \"")
end

noctalia.state.watch("cheatsheet_data", function(val)
  if type(val) == "table" then
    bindsCount = #val
  else
    bindsCount = 0
  end
  render()
end)

noctalia.state.watch("compositor", function(val)
  compositor = if type(val) == "string" then val else ""
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
