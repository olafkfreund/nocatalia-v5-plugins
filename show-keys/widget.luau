-- Show Keys — desktop widget.
-- Watches the published active key list and renders them as themed keycaps.

local keys = {}

local function render()
  local elements = {}

  for _, key in keys do
    table.insert(elements, ui.button({
      text = key,
      variant = "secondary",
    }))
  end

  desktopWidget.render(ui.row({ gap = 8, align = "center" }, elements))
end

-- Watch for key updates
noctalia.state.watch("keys", function(val)
  keys = if type(val) == "table" then val else {}
  render()
end)

function update()
  noctalia.setUpdateInterval(5000) -- Slow updates, watch callback handles rendering
  render()
end
