-- Clipboard — launcher provider.
-- Searches clipboard history, copies items, pins items, or deletes them.

local history = {}
local pinned = {}

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  if filter == "wipe" or filter == "clear" then
    table.insert(results, {
      id = "cmd:wipe",
      title = "Wipe Clipboard History",
      subtitle = "Permanently deletes all non-pinned history entries",
      glyph = "trash",
    })
  end

  for i, item in pinned do
    local preview = item.preview or ""
    local itemType = item.type or "text"
    if filter == "" or preview:lower():find(filter, 1, true) then
      table.insert(results, {
        id = `pin:{i}`,
        title = `📌 {preview}`,
        subtitle = `[PINNED {itemType:upper()}] — Press Enter to copy, Shift+Enter to unpin`,
        glyph = "clipboard"
      })
    end
  end

  for _, item in history do
    local preview = item.preview or ""
    local id = item.id or ""
    local itemType = item.type or "text"
    if filter == "" or preview:lower():find(filter, 1, true) then
      table.insert(results, {
        id = `hist:{id}:{itemType}:{preview}`,
        title = preview,
        subtitle = `[{itemType:upper()}] — Enter to copy, Shift+Enter to pin, Ctrl+Enter to delete`,
        glyph = "clipboard"
      })
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "empty",
      title = "No clipboard entries found",
      subtitle = "Search query did not match history",
      glyph = "alert-circle",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id, trigger)
  if id == "cmd:wipe" then
    noctalia.state.set("command", { action = "wipe" })
    return
  end

  if id:find("pin:", 1, true) == 1 then
    local idx = tonumber(id:match("^pin:(%d+)$"))
    if idx then
      local item = pinned[idx]
      if item then
        if trigger == "shift" then
          noctalia.state.set("command", { action = "unpin", index = idx })
        else
          noctalia.state.set("command", { action = "copy", preview = item.preview, type = item.type })
        end
      end
    end
  elseif id:find("hist:", 1, true) == 1 then
    local histId, itemType, preview = id:match("^hist:([^:]+):([^:]+):(.*)$")
    if histId then
      if trigger == "ctrl" then
        noctalia.state.set("command", { action = "delete", id = histId })
      elseif trigger == "shift" then
        noctalia.state.set("command", { action = "pin", preview = preview, type = itemType })
      else
        noctalia.state.set("command", { action = "copy", id = histId, type = itemType, preview = preview })
      end
    end
  end
end

noctalia.state.watch("history", function(val)
  history = if type(val) == "table" then val else {}
end)

noctalia.state.watch("pinned", function(val)
  pinned = if type(val) == "table" then val else {}
end)
