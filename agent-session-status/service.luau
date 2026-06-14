-- Agent Session Status — background service.
-- Spawns the python MCP HTTP server and polls it to publish session status.

noctalia.setUpdateInterval(1000)

local lastBindAddress = ""
local lastPort = 0
local lastToken = ""
local lastPollTime = 0
local scriptPath = nil
local checkedPath = false

local function getScriptPaths()
  local home = os.getenv("HOME") or "/tmp"
  return {
    "agent-session-status/server.py",
    `{home}/.local/share/noctalia/plugins/agent-session-status/server.py`,
    `{home}/.local/share/noctalia/plugins/agent-session-status-master/server.py`
  }
end

local function stopServer(port)
  if port then
    noctalia.runAsync(`pkill -f 'server.py --port {port}'`)
  end
end

local function startServer(path, host, port, token)
  stopServer(port)
  
  local cmd = `python3 '{path}' --host '{host}' --port {port}`
  if token ~= "" then
    cmd ..= ` --token '{token}'`
  end
  
  noctalia.log(`AgentSessionStatus: Spawning server: {cmd}`)
  noctalia.runStream(cmd, function(line)
    noctalia.log(`AgentSessionStatus stdout: {line}`)
  end)
end

local function pollSessions(host, port)
  local url = `http://{host}:{port}/sessions`
  noctalia.http({ url = url }, function(res)
    if res.ok then
      local success, data = pcall(noctalia.json.decode, res.body)
      if success and type(data) == "table" then
        noctalia.state.set("runningCount", tonumber(data.runningCount) or 0)
        noctalia.state.set("agents", data.agents or {})
        noctalia.state.set("serviceError", "")
        noctalia.state.set("serviceRunning", true)
        return
      end
    end
    noctalia.state.set("serviceRunning", false)
    noctalia.state.set("serviceError", noctalia.tr("service.unreachable"))
  end)
end

local function pruneInactive(host, port, token)
  noctalia.http({
    url = `http://{host}:{port}/sessions/prune-inactive`,
    method = "POST",
    headers = {
      ["Authorization"] = "Bearer " .. token
    }
  }, function(res)
    pollSessions(host, port)
  end)
end

-- Watch for commands from widget / desktop widget
noctalia.state.watch("command", function(cmd)
  local host = noctalia.getConfig("bindAddress") or "127.0.0.1"
  local port = noctalia.getConfig("port") or 55854
  local token = noctalia.getConfig("token") or ""

  if cmd == "refresh" then
    pollSessions(host, port)
  elseif cmd == "restart" then
    if scriptPath then
      startServer(scriptPath, host, port, token)
    end
  elseif cmd == "prune" then
    pruneInactive(host, port, token)
  end
end)

function update()
  local host = noctalia.getConfig("bindAddress") or "127.0.0.1"
  local port = noctalia.getConfig("port") or 55854
  local token = noctalia.getConfig("token") or ""
  local pollInterval = noctalia.getConfig("pollIntervalSec") or 2

  -- 1. Find python script path once
  if not checkedPath then
    checkedPath = true
    local paths = getScriptPaths()
    local function tryFind(idx)
      if idx > #paths then
        noctalia.log("AgentSessionStatus: server.py not found in any tested path")
        noctalia.state.set("serviceError", "server.py not found")
        return
      end
      local p = paths[idx]
      noctalia.runAsync(`test -f '{p}'`, function(res)
        if res.exitCode == 0 then
          scriptPath = p
          startServer(scriptPath, host, port, token)
          lastBindAddress = host
          lastPort = port
          lastToken = token
        else
          tryFind(idx + 1)
        end
      end)
    end
    tryFind(1)
    return
  end

  -- 2. Restart if config changed
  if scriptPath and (host ~= lastBindAddress or port ~= lastPort or token ~= lastToken) then
    stopServer(lastPort)
    startServer(scriptPath, host, port, token)
    lastBindAddress = host
    lastPort = port
    lastToken = token
    lastPollTime = 0
  end

  -- 3. Periodically poll endpoint
  local now = os.clock()
  if now - lastPollTime >= pollInterval then
    lastPollTime = now
    pollSessions(host, port)
  end
end
