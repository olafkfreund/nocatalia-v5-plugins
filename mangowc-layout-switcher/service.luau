-- MangoWC Layout Switcher — background service.
-- Manages MangoWC window layout switching via mmsg IPC.

local currentLayout = ""
local availableLayouts = {}
local monitors = {}

local function updateState()
  noctalia.state.set("currentLayout", currentLayout)
  noctalia.state.set("layoutCount", #availableLayouts)
  noctalia.state.set("layouts", table.concat(availableLayouts, ","))
end

local function refresh()
  noctalia.runAsync("mmsg get all-monitors 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    -- Parse monitor info
    local monList = {}
    for name in text:gmatch('"name":"([^"]+)"') do
      monList[#monList + 1] = name
    end
    monitors = monList
    updateState()
  end)

  noctalia.runAsync("mmsg get current-layout 2>/dev/null", function(res)
    if res.exitCode == 0 then
      currentLayout = (res.stdout or res.body or ""):gsub("\n", "")
    end
    updateState()
  end)
end

local function setLayout(layout)
  noctalia.runAsync("mmsg set layout " .. layout .. " 2>/dev/null", function(res)
    refresh()
  end)
end

local function cycleLayout()
  local layouts = {"tiled", "monocle", "floating"}
  local currentIdx = 1
  for i, l in ipairs(layouts) do
    if l == currentLayout then
      currentIdx = i
      break
    end
  end
  local nextIdx = (currentIdx % #layouts) + 1
  setLayout(layouts[nextIdx])
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd == "cycle" then
    cycleLayout()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "set" then
      setLayout(arg)
    end
  end
end)

refresh()

noctalia.setUpdateInterval(3000)

function onUpdate()
  refresh()
end
