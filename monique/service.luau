-- Monique — background service.
-- Retrieves GPU performance profiles from the monique CLI tool.

local currentProfile = ""
local installed = false

local function updateState()
  noctalia.state.set("currentProfile", currentProfile)
  noctalia.state.set("installed", installed)
end

local function refresh()
  noctalia.runAsync("which monique 2>/dev/null", function(res)
    installed = res.exitCode == 0
    if not installed then
      updateState()
      return
    end

    noctalia.runAsync("monique profile current 2>/dev/null || monique get-profile 2>/dev/null || monique status 2>/dev/null", function(profRes)
      local text = (profRes.stdout or profRes.body or ""):gsub("\n", "")
      currentProfile = text ~= "" and text or "default"
      updateState()
    end)
  end)
end

local function setProfile(name)
  noctalia.runAsync("monique profile set " .. name .. " 2>/dev/null || monique set-profile " .. name .. " 2>/dev/null", function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "set-profile" then
      setProfile(arg)
    end
  end
end)

refresh()

local interval = tonumber(noctalia.getConfig("refreshInterval")) or 2000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
