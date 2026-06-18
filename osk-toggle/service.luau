-- OSK Toggle — background service.
-- Supports Squeekboard (via gsettings + D-Bus) and wvkbd.

local available = false
local keyboardActive = false
local resolvedBackend = ""
local gsettingsOk = true

local function updateState()
  noctalia.state.set("available", available)
  noctalia.state.set("keyboardActive", keyboardActive)
  noctalia.state.set("resolvedBackend", resolvedBackend)
  noctalia.state.set("gsettingsOk", gsettingsOk)
end

-- === Squeekboard backend ===

local function squeekboardToggle()
  local newVal = "false"
  if not keyboardActive then newVal = "true" end
  noctalia.runAsync("gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled " .. newVal, function(res)
    if res.exitCode == 0 then
      keyboardActive = not keyboardActive
      updateState()
    end
  end)
end

local function squeekboardRefresh()
  noctalia.runAsync("gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled 2>/dev/null", function(res)
    if res.exitCode == 0 then
      gsettingsOk = true
      local stdout = res.stdout or res.body or ""
      local val = stdout:gsub("^%s+", ""):gsub("%s+$", "")
      keyboardActive = (val == "true")
    else
      gsettingsOk = false
    end
    updateState()
  end)
end

local function initSqueekboard(onDone)
  noctalia.runAsync("busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s sm.puri.OSK0 2>/dev/null", function(res)
    available = res.exitCode == 0
    updateState()
    squeekboardRefresh()
    if onDone then onDone() end
  end)
end

-- === wvkbd backend ===

local wvkbdVisible = false

local function wvkbdToggle()
  local bin = noctalia.getConfig("wvkbdBin") or "wvkbd-mobintl"
  if wvkbdVisible then
    noctalia.runAsync("pkill -x " .. bin, function(res)
      wvkbdVisible = false
      keyboardActive = false
      updateState()
    end)
  else
    noctalia.runAsync(bin .. " --hidden &", function(res)
      wvkbdVisible = true
      keyboardActive = true
      updateState()
    end)
  end
end

local function initWvkbd(onDone)
  local bin = noctalia.getConfig("wvkbdBin") or "wvkbd-mobintl"
  noctalia.runAsync("command -v " .. bin .. " 2>/dev/null", function(res)
    available = res.exitCode == 0
    keyboardActive = false
    updateState()
    if onDone then onDone() end
  end)
end

-- === Backend resolution ===

local function resolveBackend(backendCfg, onDone)
  if backendCfg == "squeekboard" then
    resolvedBackend = "squeekboard"
    initSqueekboard(onDone)
  elseif backendCfg == "wvkbd" then
    resolvedBackend = "wvkbd"
    initWvkbd(onDone)
  else
    -- auto: try squeekboard first
    noctalia.runAsync("busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s sm.puri.OSK0 2>/dev/null", function(res)
      if res.exitCode == 0 then
        resolvedBackend = "squeekboard"
        initSqueekboard(onDone)
      else
        resolvedBackend = "wvkbd"
        initWvkbd(onDone)
      end
    end)
  end
end

-- === IPC and state commands ===

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    if resolvedBackend == "squeekboard" then
      squeekboardToggle()
    elseif resolvedBackend == "wvkbd" then
      wvkbdToggle()
    end
  elseif cmd == "refresh" then
    if resolvedBackend == "squeekboard" then
      squeekboardRefresh()
    end
  end
end)

-- === Init ===

local backendCfg = noctalia.getConfig("backend") or "auto"
resolveBackend(backendCfg, nil)

-- Poll keyboard state every 5 seconds for squeekboard
noctalia.setUpdateInterval(5000)

function onUpdate()
  if resolvedBackend == "squeekboard" then
    squeekboardRefresh()
  end
end
