-- ASUS UM5606 Fan State — background service.
-- Periodically checks fan state and handles state changes.

noctalia.setUpdateInterval(2000)

local lastFanState = -1
local lastFileMtime = ""

local function checkFanState()
  noctalia.runAsync("fan_state get --int", function(res)
    if res.exitCode == 0 then
      local val = tonumber(res.stdout:gsub("%s+", ""))
      if val and val ~= lastFanState then
        lastFanState = val
        noctalia.state.set("fanState", val)
      end
    end
  end)
end

-- Watch for state changes from the runtime file
local function checkFileChange()
  noctalia.runAsync("stat -c %Y $XDG_RUNTIME_DIR/fan_state 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local mtime = res.stdout:gsub("%s+", "")
      if mtime ~= lastFileMtime then
        lastFileMtime = mtime
        checkFanState()
      end
    else
      -- Fallback to periodic check if stat fails
      checkFanState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) == "table" and cmd.action == "set" then
    local val = tonumber(cmd.value)
    if val then
      noctalia.runAsync(`fan_state set {val}`, function(res)
        checkFanState()
      end)
    end
  end
end)

function update()
  checkFileChange()
end
