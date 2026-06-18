-- Notes Scratchpad — background service.
-- Manages a simple scratchpad text file for quick notes.

local content = ""
local charCount = 0

local function getScratchpadPath()
  return os.getenv("HOME") .. "/.local/share/noctalia/scratchpad.txt"
end

local function updateState()
  noctalia.state.set("content", content)
  noctalia.state.set("charCount", charCount)
end

local function load()
  noctalia.runAsync("cat " .. getScratchpadPath() .. " 2>/dev/null", function(res)
    if res.exitCode == 0 then
      content = res.stdout or res.body or ""
    else
      content = noctalia.getConfig("scratchpadContent") or ""
    end
    charCount = #content
    updateState()
  end)
end

local function save(text)
  local path = getScratchpadPath()
  noctalia.runAsync("mkdir -p $(dirname " .. path .. ")", function(res)
    -- Write content to file using a temp file approach
    local tmpPath = path .. ".tmp"
    noctalia.runAsync("cat > " .. tmpPath .. " << 'ENDOFCONTENT'\n" .. text .. "\nENDOFCONTENT", function(res2)
      noctalia.runAsync("mv " .. tmpPath .. " " .. path, function(res3)
        content = text
        charCount = #text
        updateState()
      end)
    end)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "load" then
    load()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.*)$")
    if action == "save" then
      save(arg or "")
    end
  end
end)

load()

noctalia.setUpdateInterval(0)
