-- Niri Workspaces — background service.
-- Lists and manages Niri workspaces via `niri msg`.

local workspaces = {}
local activeWorkspace = 0
local workspaceCount = 0

local function updateState()
  local names = {}
  for _, ws in ipairs(workspaces) do
    names[#names + 1] = ws.name or tostring(ws.idx)
  end
  noctalia.state.set("workspaceNames", table.concat(names, ","))
  noctalia.state.set("activeWorkspace", activeWorkspace)
  noctalia.state.set("workspaceCount", workspaceCount)
end

local function refresh()
  noctalia.runAsync("niri msg -j workspaces 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      workspaces = {}
      workspaceCount = 0
      updateState()
      return
    end
    local text = res.stdout or res.body or ""
    local wsList = {}
    local active = 0
    -- Parse JSON workspaces array
    for idx, isActive, name in text:gmatch('"idx":(%d+).*?"is_active":(true|false).*?"name":"([^"]*)"') do
      local n = tonumber(idx) or 0
      if name == "" then name = tostring(n) end
      wsList[#wsList + 1] = {idx = n, name = name, active = isActive == "true"}
      if isActive == "true" then
        active = n
      end
    end
    workspaces = wsList
    activeWorkspace = active
    workspaceCount = #wsList
    updateState()
  end)
end

local function focusWorkspace(ref)
  noctalia.runAsync("niri msg action focus-workspace " .. tostring(ref) .. " 2>/dev/null", function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "focus" then
      focusWorkspace(arg)
    end
  end
end)

refresh()

noctalia.setUpdateInterval(2000)

function onUpdate()
  refresh()
end
