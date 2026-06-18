-- Openhue — background service.
-- Controls Philips Hue lights via the openhue CLI.

local lights = {}
local available = false
local anyOn = false

local function updateState()
  noctalia.state.set("available", available)
  noctalia.state.set("anyOn", anyOn)
  noctalia.state.set("lightCount", #lights)
end

local function refresh()
  noctalia.runAsync("openhue get lights 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      available = false
      updateState()
      return
    end
    available = true
    local text = res.stdout or res.body or ""
    -- Count lights and check if any are on
    local lightList = {}
    local onCount = 0
    for line in text:gmatch("[^\n]+") do
      local id, name, state = line:match("([%w%-]+)%s+(.-)%s+(on|off)")
      if id then
        lightList[#lightList + 1] = {id = id, name = name, on = state == "on"}
        if state == "on" then onCount = onCount + 1 end
      end
    end
    lights = lightList
    anyOn = onCount > 0
    updateState()
  end)
end

local function setLight(id, state)
  local stateFlag = state and "--on" or "--off"
  noctalia.runAsync("openhue set light " .. id .. " " .. stateFlag .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function toggleAll()
  local newState = not anyOn
  for _, light in ipairs(lights) do
    setLight(light.id, newState)
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "toggle-all" then
    toggleAll()
  elseif cmd then
    local action, id = cmd:match("^([^:]+):(.+)$")
    if action == "on" then
      setLight(id, true)
    elseif action == "off" then
      setLight(id, false)
    elseif action == "toggle" then
      for _, light in ipairs(lights) do
        if light.id == id then
          setLight(id, not light.on)
          break
        end
      end
    end
  end
end)

refresh()

noctalia.setUpdateInterval(10000)

function onUpdate()
  refresh()
end
