-- Simple Notes — background service.
-- Manages a simple text notes file.

local noteCount = 0
local notesContent = ""

local function getNotesPath()
  local configPath = noctalia.getConfig("notesFile") or ""
  if configPath == "" then
    configPath = os.getenv("HOME") .. "/.local/share/noctalia/simple-notes.txt"
  end
  return configPath
end

local function loadNotes()
  local path = getNotesPath()
  noctalia.runAsync("cat " .. path .. " 2>/dev/null", function(res)
    if res.exitCode == 0 then
      notesContent = res.stdout or res.body or ""
      -- Count lines as notes
      local count = 0
      for _ in notesContent:gmatch("[^\n]+") do count = count + 1 end
      noteCount = count
    else
      noteCount = 0
      notesContent = ""
    end
    noctalia.state.set("noteCount", noteCount)
    noctalia.state.set("notesContent", notesContent)
  end)
end

local function saveNote(text)
  if text == "" then return end
  local path = getNotesPath()
  -- Create directory if needed
  noctalia.runAsync("mkdir -p $(dirname " .. path .. ")", function(res)
    noctalia.runAsync("echo '" .. text:gsub("'", "'\\''") .. "' >> " .. path, function(res2)
      loadNotes()
    end)
  end)
end

local function clearNotes()
  local path = getNotesPath()
  noctalia.runAsync("rm -f " .. path, function(res)
    noteCount = 0
    notesContent = ""
    noctalia.state.set("noteCount", noteCount)
    noctalia.state.set("notesContent", notesContent)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    loadNotes()
  elseif cmd == "clear" then
    clearNotes()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "add" then
      saveNote(arg)
    end
  end
end)

loadNotes()

noctalia.setUpdateInterval(0)
