-- Clipper — launcher provider.
-- Manage clipboard history, pinned items, and sticky notes/notecards.

local history = {}
local pinned = {}
local notecards = {}

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  local noteTitle, noteContent = filter:match("^note%s+(%S+)%s+(.*)$")
  if noteTitle and noteContent then
    table.insert(results, {
      id = `cmd:create-note:{noteTitle}:{noteContent}`,
      title = `Create Notecard: {noteTitle}`,
      subtitle = `Content: {noteContent}`,
      glyph = "note"
    })
  end

  if filter == "wipe" or filter == "clear" then
    table.insert(results, {
      id = "cmd:wipe",
      title = "Wipe Clipboard History",
      subtitle = "Permanently deletes all non-pinned history entries",
      glyph = "trash",
    })
  end

  for _, note in notecards do
    local title = note.title or ""
    local content = note.content or ""
    if filter == "" or title:lower():find(filter, 1, true) or content:lower():find(filter, 1, true) then
      table.insert(results, {
        id = `note:{note.filename}`,
        title = `📝 {title}`,
        subtitle = `{content:sub(1, 60)}... (Shift+Enter to delete note)`,
        glyph = "note"
      })
    end
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
      title = "Clipper Provider",
      subtitle = "Type '/clipper note <title> <content>' to create sticky notes",
      glyph = "notes",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id, trigger)
  if id:find("cmd:create-note:", 1, true) == 1 then
    local title, content = id:match("^cmd:create-note:([^:]+):(.*)$")
    if title and content then
      noctalia.state.set("command", { action = "save-note", title = title, content = content })
    end
    return
  end

  if id == "cmd:wipe" then
    noctalia.state.set("command", { action = "wipe" })
    return
  end

  if id:find("note:", 1, true) == 1 then
    local filename = id:match("^note:(.*)$")
    if filename then
      if trigger == "shift" then
        noctalia.state.set("command", { action = "delete-note", filename = filename })
      else
        for _, note in notecards do
          if note.filename == filename then
            noctalia.copyToClipboard(note.content, "text/plain")
            noctalia.notify("Clipper", `Copied note '{note.title}' to clipboard`)
            break
          end
        end
      end
    end
  elseif id:find("pin:", 1, true) == 1 then
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

noctalia.state.watch("notecards", function(val)
  notecards = if type(val) == "table" then val else {}
end)
