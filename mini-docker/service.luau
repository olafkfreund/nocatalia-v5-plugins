-- Mini Docker — background service.
-- Polls Docker container status via `docker ps`.

local runningCount = 0
local totalCount = 0
local dockerAvailable = false

local function updateState()
  noctalia.state.set("runningCount", runningCount)
  noctalia.state.set("totalCount", totalCount)
  noctalia.state.set("dockerAvailable", dockerAvailable)
end

local function refresh()
  noctalia.runAsync("docker ps -q 2>/dev/null | wc -l", function(res)
    if res.exitCode ~= 0 then
      dockerAvailable = false
      updateState()
      return
    end
    dockerAvailable = true
    runningCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
    updateState()
  end)

  noctalia.runAsync("docker ps -aq 2>/dev/null | wc -l", function(res)
    if res.exitCode == 0 then
      totalCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
      updateState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "start-all" then
    noctalia.runAsync("docker start $(docker ps -aq) 2>/dev/null", function(res)
      refresh()
    end)
  elseif cmd == "stop-all" then
    noctalia.runAsync("docker stop $(docker ps -q) 2>/dev/null", function(res)
      refresh()
    end)
  end
end)

refresh()

local interval = (tonumber(noctalia.getConfig("refreshInterval")) or 5) * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
