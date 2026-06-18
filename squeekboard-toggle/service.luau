-- Squeekboard Toggle — background service.
-- Checks Squeekboard availability and keyboard state via gsettings and busctl.

local gsettingsOk = false
local squeekboardOk = false
local keyboardActive = false

local function updateState()
  local available = gsettingsOk and squeekboardOk
  noctalia.state.set("available", available)
  noctalia.state.set("keyboardActive", keyboardActive)
  noctalia.state.set("gsettingsOk", gsettingsOk)
end

local function checkSqueekboard(callback)
  noctalia.runAsync("busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s sm.puri.OSK0 2>/dev/null", function(res)
    squeekboardOk = res.exitCode == 0
    updateState()
    if callback then callback() end
  end)
end

local function checkKeyboardState()
  noctalia.runAsync("gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled 2>/dev/null", function(res)
    local stdout = ""
    if res.exitCode == 0 then
      stdout = res.stdout or res.body or ""
      gsettingsOk = true
      local val = stdout:gsub("^%s+", ""):gsub("%s+$", "")
      keyboardActive = (val == "true")
    else
      gsettingsOk = false
      keyboardActive = false
    end
    updateState()
  end)
end

local function toggleKeyboard()
  if not (gsettingsOk and squeekboardOk) then return end
  local newVal = "true"
  if keyboardActive then newVal = "false" end
  noctalia.runAsync("gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled " .. newVal, function(res)
    if res.exitCode == 0 then
      keyboardActive = not keyboardActive
      updateState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    toggleKeyboard()
  elseif cmd == "refresh" then
    checkKeyboardState()
    checkSqueekboard(nil)
  end
end)

-- Initial check
checkSqueekboard(function()
  checkKeyboardState()
end)

-- Poll for keyboard state changes every 3 seconds
noctalia.setUpdateInterval(3000)

function onUpdate()
  checkKeyboardState()
end
