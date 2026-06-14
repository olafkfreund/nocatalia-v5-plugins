-- Clipper — background service.
-- Periodically pulls clipboard history from cliphist and manages commands (pin, copy, delete, wipe, save-note, delete-note).

noctalia.setUpdateInterval(2000)

local lastHistory = ""
local historyList = {}
local pinnedList = {}
local pinnedLoaded = false
local noteList = {}
local notesLoaded = false

local function getNotesDir()
  local home = os.getenv("HOME") or "/tmp"
  return `{home}/.config/noctalia/plugins/clipper/notecards`
end

local function loadPinned()
  local home = os.getenv("HOME") or "/tmp"
  local path = `{home}/.config/noctalia/plugins/clipper/pinned.json`
  noctalia.runAsync(`test -f '{path}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`cat '{path}'`, function(catRes)
        local success, parsed = pcall(noctalia.json.decode, catRes.stdout or catRes.body)
        if success and type(parsed) == "table" and type(parsed.items) == "table" then
          pinnedList = parsed.items
        end
        pinnedLoaded = true
      end)
    else
      pinnedLoaded = true
    end
  end)
end

local function savePinned()
  if not pinnedLoaded then return end
  local home = os.getenv("HOME") or "/tmp"
  local dir = `{home}/.config/noctalia/plugins/clipper`
  local path = `{dir}/pinned.json`
  local payload = noctalia.json.encode({ items = pinnedList })
  noctalia.runAsync(`mkdir -p '{dir}'`, function(res)
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{payload:gsub("'", "'\\''")}' '{path}'`)
  end)
end

local function updateNotes()
  local dir = getNotesDir()
  noctalia.runAsync(`mkdir -p '{dir}' && ls -1 '{dir}'`, function(res)
    if res.exitCode == 0 then
      local files = {}
      for file in (res.stdout or res.body or ""):gmatch("[^\r\n]+") do
        table.insert(files, file)
      end
      
      local parsedNotes = {}
      local pending = #files
      if pending == 0 then
        noteList = parsedNotes
        noctalia.state.set("notecards", noteList)
        notesLoaded = true
        return
      end

      for _, file in files do
        local filePath = `{dir}/{file}`
        noctalia.runAsync(`cat '{filePath}'`, function(catRes)
          if catRes.exitCode == 0 then
            table.insert(parsedNotes, {
              filename = file,
              title = file:gsub("%.txt$", ""),
              content = catRes.stdout or catRes.body or ""
            })
          end
          pending -= 1
          if pending == 0 then
            noteList = parsedNotes
            noctalia.state.set("notecards", noteList)
            notesLoaded = true
          end
        end)
      end
    end
  end)
end

local function saveNote(title, content)
  local dir = getNotesDir()
  local filename = `{title:gsub("[^%w%-_]", "_")}.txt`
  local path = `{dir}/{filename}`
  noctalia.runAsync(`mkdir -p '{dir}'`, function()
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{content:gsub("'", "'\\''")}' '{path}'`, function(res)
      updateNotes()
    end)
  end)
end

local function deleteNote(filename)
  local dir = getNotesDir()
  local path = `{dir}/{filename}`
  noctalia.runAsync(`rm -f '{path}'`, function()
    updateNotes()
  end)
end

local function updateHistory()
  noctalia.runAsync(`cliphist list | head -n 100`, function(res)
    if res.exitCode == 0 then
      local raw = res.stdout or res.body or ""
      if raw == lastHistory then return end
      lastHistory = raw
      
      local parsed = {}
      for line in raw:gmatch("[^\r\n]+") do
        local tab = line:find("\t")
        if tab then
          local id = line:sub(1, tab - 1)
          local preview = line:sub(tab + 1)
          local itemType = "text"
          if preview:match("^%[%[%s*binary data") then
            itemType = "image"
          elseif preview:match("^file://") or preview:match("^/") then
            itemType = "file"
          end
          table.insert(parsed, { id = id, preview = preview, type = itemType })
        end
      end
      historyList = parsed
      noctalia.state.set("history", historyList)
    end
  end)
end

-- Initialize
loadPinned()
updateNotes()

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  
  if cmd.action == "copy" then
    local id = cmd.id
    local itemType = cmd.type
    local preview = cmd.preview
    if itemType == "file" then
      local uri = if preview:find("file://", 1, true) == 1 then preview else `file://{preview}`
      noctalia.runAsync(`bash -c 'printf "copy\\n%s\\n" "$1" | wl-copy --type x-special/gnome-copied-files' -- '{uri}'`)
    else
      noctalia.runAsync(`cliphist decode {id} | wl-copy`)
    end
    noctalia.notify("Clipper", "Item copied to clipboard")
  elseif cmd.action == "delete" then
    local id = cmd.id
    noctalia.runAsync(`cliphist list | grep -Pm1 "^{id}\\t" | cliphist delete`, function(res)
      updateHistory()
      noctalia.notify("Clipper", "Item removed from history")
    end)
  elseif cmd.action == "wipe" then
    noctalia.runAsync("cliphist wipe", function(res)
      updateHistory()
      noctalia.notify("Clipper", "Clipboard history wiped")
    end)
  elseif cmd.action == "pin" then
    local preview = cmd.preview
    local itemType = cmd.type
    local isDup = false
    for _, item in pinnedList do
      if item.preview == preview and item.type == itemType then
        isDup = true
        break
      end
    end
    if not isDup then
      table.insert(pinnedList, 1, { preview = preview, type = itemType })
      savePinned()
      noctalia.state.set("pinned", pinnedList)
      noctalia.notify("Clipper", "Item pinned")
    end
  elseif cmd.action == "unpin" then
    local idx = cmd.index
    if idx and pinnedList[idx] then
      table.remove(pinnedList, idx)
      savePinned()
      noctalia.state.set("pinned", pinnedList)
      noctalia.notify("Clipper", "Item unpinned")
    end
  elseif cmd.action == "save-note" then
    saveNote(cmd.title, cmd.content)
    noctalia.notify("Clipper", `Note '{cmd.title}' saved`)
  elseif cmd.action == "delete-note" then
    deleteNote(cmd.filename)
    noctalia.notify("Clipper", "Note deleted")
  end
end)

function update()
  updateHistory()
  if pinnedLoaded then
    noctalia.state.set("pinned", pinnedList)
  end
  if notesLoaded then
    noctalia.state.set("notecards", noteList)
  end
end
