-- OBS Control — bar widget.

local obsRunning = false
local isRecording = false
local isStreaming = false
local recordingTime = ""

local function render()
  local showWhenRecording = barWidget.getConfig("showBarWhenRecording") ~= false
  local showWhenStreaming = barWidget.getConfig("showBarWhenStreaming") ~= false
  local showWhenReady = barWidget.getConfig("showBarWhenReady") ~= false

  if not obsRunning then
    if showWhenReady then
      barWidget.setVisible(true)
      barWidget.setGlyph("video")
      barWidget.setGlyphColor("on_surface_variant")
      barWidget.setText("")
      barWidget.setTooltip("OBS: Not running — click to start")
    else
      barWidget.setVisible(false)
    end
    return
  end

  barWidget.setVisible(true)
  barWidget.setGlyph("video")

  if isRecording then
    barWidget.setGlyphColor("error")
    local label = "REC"
    if recordingTime ~= "" then label = label .. " " .. recordingTime end
    barWidget.setText(label)
    barWidget.setTooltip("OBS: Recording" .. (recordingTime ~= "" and " (" .. recordingTime .. ")" or "") .. " — click to stop")
  elseif isStreaming then
    barWidget.setGlyphColor("primary")
    barWidget.setText("LIVE")
    barWidget.setTooltip("OBS: Streaming — click to stop stream")
  else
    if showWhenReady then
      barWidget.setGlyphColor("on_surface")
      barWidget.setText("")
      barWidget.setTooltip("OBS: Ready — click to record")
    else
      barWidget.setVisible(false)
    end
  end
end

function onClick()
  if not obsRunning then
    noctalia.state.set("command", "start-obs")
  else
    noctalia.state.set("command", "toggle-record")
  end
end

function onRightClick()
  if obsRunning then
    noctalia.state.set("command", "toggle-stream")
  else
    noctalia.state.set("command", "refresh")
  end
end

noctalia.state.watch("obsRunning", function(val)
  obsRunning = val == true
  render()
end)

noctalia.state.watch("isRecording", function(val)
  isRecording = val == true
  render()
end)

noctalia.state.watch("isStreaming", function(val)
  isStreaming = val == true
  render()
end)

noctalia.state.watch("recordingTime", function(val)
  recordingTime = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
