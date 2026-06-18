-- News — bar widget.
-- Displays rolling news headlines in the bar.

local currentHeadline = ""
local headlineCount = 0
local isLoading = false
local errorMsg = ""

local function render()
  barWidget.setGlyph("newspaper")

  if isLoading then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("...")
    barWidget.setTooltip("Loading news...")
    return
  end

  if errorMsg ~= "" then
    barWidget.setGlyphColor("error")
    barWidget.setText("")
    barWidget.setTooltip("News: " .. errorMsg)
    return
  end

  if headlineCount == 0 then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("No headlines")
    return
  end

  barWidget.setGlyphColor("on_surface")
  -- Truncate long headlines for bar display
  local display = currentHeadline
  if #display > 50 then
    display = display:sub(1, 47) .. "..."
  end
  barWidget.setText(display)
  barWidget.setTooltip(currentHeadline .. "\n\n" .. headlineCount .. " headlines — click to advance")
end

function onClick()
  noctalia.state.set("command", "next")
end

function onRightClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("currentHeadline", function(val)
  currentHeadline = val or ""
  render()
end)

noctalia.state.watch("headlineCount", function(val)
  headlineCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("isLoading", function(val)
  isLoading = val == true
  render()
end)

noctalia.state.watch("errorMsg", function(val)
  errorMsg = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
