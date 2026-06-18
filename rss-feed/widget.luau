-- RSS Feed — bar widget.

local unreadCount = 0
local totalItems = 0
local latestTitle = ""

local function render()
  if unreadCount > 0 then
    barWidget.setGlyph("rss")
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(unreadCount))
    local tooltip = unreadCount .. " unread items"
    if latestTitle ~= "" then
      tooltip = tooltip .. " | " .. latestTitle
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyph("rss")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    if totalItems > 0 then
      barWidget.setTooltip("All " .. totalItems .. " items read")
    else
      barWidget.setTooltip("RSS Feed — no items")
    end
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

function onRightClick()
  noctalia.state.set("command", "markAllRead")
end

noctalia.state.watch("unreadCount", function(val)
  unreadCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("totalItems", function(val)
  totalItems = tonumber(val) or 0
  render()
end)

noctalia.state.watch("latestTitle", function(val)
  latestTitle = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
