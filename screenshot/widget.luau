-- Screenshot — bar widget.

local function render()
  barWidget.setGlyph("camera")
  barWidget.setText("")
  barWidget.setTooltip(noctalia.tr("tooltip") or "Take a screenshot")
end

function onClick()
  local mode = barWidget.getConfig("mode") or "region"
  noctalia.state.set("command", { action = "take", mode = mode })
end

function update()
  noctalia.setUpdateInterval(0)
  render()
end
