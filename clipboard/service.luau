-- Clipboard — background service.
-- Periodically pulls clipboard history from cliphist and manages commands (pin, copy, delete, wipe).

noctalia.setUpdateInterval(2000) -- Check history every 2 seconds

local lastHistory = ""
local historyList = {}
local pinnedList = {}
local pinnedLoaded = false

local function loadPinned()
  local home = os.getenv("HOME") or "/tmp"
  local path = `{home}/.cache/noctalia/plugins/clipboard/pinned.json`
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
  local dir = `{home}/.cache/noctalia/plugins/clipboard`
  local path = `{dir}/pinned.json`
  local payload = noctalia.json.encode({ items = pinnedList })
  noctalia.runAsync(`mkdir -p '{dir}'`, function(res)
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{payload:gsub("'", "'\\''")}' '{path}'`)
  end)
end

local function updateHistory()
  local max = noctalia.getConfig("maxHistorySize") or 100
  noctalia.runAsync(`cliphist list | head -n {max}`, function(res)
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
    noctalia.notify("Clipboard", "Item copied to clipboard")
  elseif cmd.action == "delete" then
    local id = cmd.id
    noctalia.runAsync(`cliphist list | grep -Pm1 "^{id}\\t" | cliphist delete`, function(res)
      updateHistory()
      noctalia.notify("Clipboard", "Item removed from history")
    end)
  elseif cmd.action == "wipe" then
    noctalia.runAsync("cliphist wipe", function(res)
      updateHistory()
      noctalia.notify("Clipboard", "Clipboard history wiped")
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
      noctalia.notify("Clipboard", "Item pinned")
    end
  elseif cmd.action == "unpin" then
    local idx = cmd.index
    if idx and pinnedList[idx] then
      table.remove(pinnedList, idx)
      savePinned()
      noctalia.state.set("pinned", pinnedList)
      noctalia.notify("Clipboard", "Item unpinned")
    end
  end
end)

function update()
  updateHistory()
  if pinnedLoaded then
    noctalia.state.set("pinned", pinnedList)
  end
end
