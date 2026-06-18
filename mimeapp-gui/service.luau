-- MIME App GUI — background service.
-- Manages MIME type app associations via xdg-mime.

local mimeTypes = {}
local typeCount = 0

local function updateState()
  noctalia.state.set("typeCount", typeCount)
end

local function listMimeApps()
  noctalia.runAsync("cat ~/.config/mimeapps.list 2>/dev/null | grep -c = || echo 0", function(res)
    typeCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
    updateState()
  end)
end

local function setMimeApp(mimeType, app)
  noctalia.runAsync("xdg-mime default " .. app .. " " .. mimeType .. " 2>/dev/null", function(res)
    listMimeApps()
  end)
end

local function getMimeApp(mimeType)
  noctalia.runAsync("xdg-mime query default " .. mimeType .. " 2>/dev/null", function(res)
    local app = (res.stdout or res.body or ""):gsub("\n", "")
    noctalia.state.set("defaultApp", app)
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    listMimeApps()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "get" then
      getMimeApp(arg)
    elseif action == "set" then
      local mimeType, app = arg:match("^([^|]+)|(.+)$")
      if mimeType and app then
        setMimeApp(mimeType, app)
      end
    end
  end
end)

listMimeApps()

noctalia.setUpdateInterval(0)
