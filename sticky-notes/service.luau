-- Sticky Notes — background service.
-- Manages sticky notes with optional GitHub Gist sync.

local noteCount = 0

local function updateState()
  noctalia.state.set("noteCount", noteCount)
end

local function getNotesFile()
  return os.getenv("HOME") .. "/.local/share/noctalia/sticky-notes.json"
end

local function loadNotes()
  noctalia.runAsync("cat " .. getNotesFile() .. " 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local text = res.stdout or res.body or ""
      local count = 0
      for _ in text:gmatch('"id"') do count = count + 1 end
      noteCount = count
    else
      local notesJson = noctalia.getConfig("notes") or "[]"
      local count = 0
      for _ in notesJson:gmatch('"id"') do count = count + 1 end
      noteCount = count
    end
    updateState()
  end)
end

local function syncFromGist()
  local token = noctalia.getConfig("githubToken") or ""
  local gistId = noctalia.getConfig("githubGistId") or ""
  if token == "" or gistId == "" then return end

  local cmd = 'curl -s --max-time 15 -H "Authorization: token ' .. token .. '" "https://api.github.com/gists/' .. gistId .. '" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      loadNotes()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    loadNotes()
  elseif cmd == "sync" then
    syncFromGist()
  end
end)

loadNotes()

local syncEnabled = noctalia.getConfig("syncEnabled") == true
if syncEnabled then
  syncFromGist()
end

noctalia.setUpdateInterval(0)
