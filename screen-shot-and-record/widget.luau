-- Screenshot & Screen Record — bar widget.

local isRecording = false

local function render()
  if isRecording then
    barWidget.setGlyph("video")
    barWidget.setGlyphColor("error")
    barWidget.setText("REC")
    barWidget.setTooltip("Recording in progress — click to stop")
  else
    barWidget.setGlyph("screenshot")
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    barWidget.setTooltip("Screenshot — click for screen, right-click for area")
  end
end

function onClick()
  if isRecording then
    noctalia.state.set("command", "toggle-record")
  else
    noctalia.state.set("command", "screenshot")
  end
end

function onRightClick()
  if isRecording then
    noctalia.state.set("command", "toggle-record")
  else
    noctalia.state.set("command", "screenshot-area")
  end
end

noctalia.state.watch("isRecording", function(val)
  isRecording = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
