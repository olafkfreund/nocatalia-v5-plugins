-- Weekly Calendar — bar widget.

local today = ""
local weekday = ""
local weekNum = ""

local function render()
  barWidget.setGlyph("calendar")
  barWidget.setGlyphColor("on_surface")

  if today ~= "" then
    -- Extract day number for display
    local dayNum = today:match("%d+$") or today
    barWidget.setText(dayNum)
    barWidget.setTooltip(weekday .. ", " .. today .. " (Week " .. weekNum .. ")")
  else
    barWidget.setText("")
    barWidget.setTooltip("Weekly Calendar")
  end
end

function onClick()
  -- just a refresh trigger
end

noctalia.state.watch("today", function(val)
  today = val or ""
  render()
end)

noctalia.state.watch("weekday", function(val)
  weekday = val or ""
  render()
end)

noctalia.state.watch("weekNum", function(val)
  weekNum = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
