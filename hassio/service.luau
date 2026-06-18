-- Home Assistant Control — background service.
-- Queries Home Assistant entity states via REST API.

local entityStates = {}
local errorMessage = ""
local connected = false

local function updateState()
  noctalia.state.set("connected", connected)
  noctalia.state.set("errorMessage", errorMessage)
  -- Convert entity states to JSON string
  local parts = {}
  for entityId, state in pairs(entityStates) do
    parts[#parts + 1] = '"' .. entityId .. '":"' .. tostring(state) .. '"'
  end
  noctalia.state.set("entityStates", "{" .. table.concat(parts, ",") .. "}")
end

local function fetchStates()
  local url = noctalia.getConfig("haUrl") or "http://homeassistant.local:8123"
  local token = noctalia.getConfig("haToken") or ""
  if token == "" then
    errorMessage = "No token configured"
    connected = false
    updateState()
    return
  end

  local cmd = 'curl -s --max-time 10 -H "Authorization: Bearer ' .. token .. '" -H "Content-Type: application/json" "' .. url .. '/api/states" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then
      connected = false
      errorMessage = "Connection failed"
      updateState()
      return
    end
    connected = true
    errorMessage = ""
    local text = res.stdout or res.body or ""
    -- Parse entity states
    entityStates = {}
    for entityId, state in text:gmatch('"entity_id":"([^"]+)"[^}]+"state":"([^"]+)"') do
      entityStates[entityId] = state
    end
    updateState()
  end)
end

local function toggleEntity(entityId)
  local url = noctalia.getConfig("haUrl") or "http://homeassistant.local:8123"
  local token = noctalia.getConfig("haToken") or ""
  local domain = entityId:match("^([^.]+)")
  local cmd = 'curl -s --max-time 10 -X POST -H "Authorization: Bearer ' .. token .. '" -H "Content-Type: application/json" -d \'{"entity_id": "' .. entityId .. '"}\' "' .. url .. '/api/services/' .. domain .. '/toggle" 2>/dev/null'
  noctalia.runAsync(cmd, function(res)
    fetchStates()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    fetchStates()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "toggle" then
      toggleEntity(arg)
    end
  end
end)

fetchStates()

noctalia.setUpdateInterval(10000)

function onUpdate()
  fetchStates()
end
