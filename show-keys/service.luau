-- Show Keys — background service.
-- Runs evtest and parses keystrokes, publishing active keys to noctalia.state.

noctalia.setUpdateInterval(250) -- Tick 4 times a second

local keyList = {}
local maxKeys = 12
local shiftHeld = false
local ctrlHeld = false
local altHeld = false
local metaHeld = false
local capsLockOn = false
local comboEmitted = false

local lastEventTime = 0
local isOsdVisible = false
local isStreamRunning = false
local activeDevice = nil
local lastEnabled = nil
local lastDevice = nil
local startAttempts = 0
local lastAttemptTime = 0

local shiftMap = {
  ["1"] = "!",  ["2"] = "@",  ["3"] = "#",  ["4"] = "$",  ["5"] = "%",
  ["6"] = "^",  ["7"] = "&",  ["8"] = "*",  ["9"] = "(",  ["0"] = ")",
  MINUS = "_",       EQUAL = "+",
  LEFTBRACE = "{",   RIGHTBRACE = "}",
  SEMICOLON = ":",   APOSTROPHE = "\"",
  GRAVE = "~",       BACKSLASH = "|",
  COMMA = "<",       DOT = ">",  SLASH = "?"
}

local normalMap = {
  MINUS = "-",       EQUAL = "=",
  LEFTBRACE = "[",   RIGHTBRACE = "]",
  SEMICOLON = ";",   APOSTROPHE = "'",
  GRAVE = "`",       BACKSLASH = "\\",
  COMMA = ",",       DOT = ".",  SLASH = "/"
}

local specialMap = {
  BACKSPACE = "󰁮",  ENTER = "󰌑",   ESC = "󱊷",
  SPACE = "󱁐",      TAB = "󰌒",     DELETE = "󰆴",
  UP = "↑",         DOWN = "↓",    LEFT = "←",   RIGHT = "→",
  HOME = "Home",    END = "End",
  PAGEUP = "PgUp",  PAGEDOWN = "PgDn",
  INSERT = "Ins",   CAPSLOCK = "Caps",
  NUMLOCK = "Num",  SCROLLLOCK = "Scr",
  SYSRQ = "PrtSc",  PAUSE = "Pause"
}

local function getModPrefix()
  local p = ""
  if metaHeld then p ..= "󰴈 +" end
  if ctrlHeld then p ..= "CTRL+" end
  if altHeld then p ..= "ALT+" end
  return p
end

local function isShiftConsumed(keycode)
  if not shiftHeld then return false end
  if keycode:match("^%d$") then return true end
  if shiftMap[keycode] ~= nil then return true end
  if keycode:match("^[A-Z]$") then return false end
  return false
end

local function getKeyLabel(keycode)
  if specialMap[keycode] ~= nil then
    return specialMap[keycode]
  end
  if keycode:match("^F%d+$") then
    return keycode
  end
  if keycode:find("^KP") == 1 then
    return keycode
  end

  if keycode:match("^[A-Z]$") then
    if capsLockOn then
      return keycode
    else
      return keycode:lower()
    end
  end

  if shiftHeld and shiftMap[keycode] ~= nil then
    return shiftMap[keycode]
  end

  if keycode:match("^%d$") then
    return keycode
  end

  if normalMap[keycode] ~= nil then
    return normalMap[keycode]
  end

  return keycode
end

local function emitDisplay(display)
  if #keyList >= maxKeys then
    keyList = {}
  end
  table.insert(keyList, display)
  noctalia.state.set("keys", keyList)
  
  lastEventTime = os.clock()
  isOsdVisible = true
end

local function handleLine(line)
  if not line:find("type 1 %(EV_KEY%)") then return end

  local keycode, valueStr = line:match("%(KEY_([^)]+)%).*value (%d+)")
  if not keycode or not valueStr then return end

  local value = tonumber(valueStr)
  if value == 2 then return end -- ignore repeat

  local isMod = false
  local modName = ""
  if keycode:match("SHIFT$") then
    isMod = true
    modName = "SHIFT"
  elseif keycode:match("CTRL$") then
    isMod = true
    modName = "CTRL"
  elseif keycode:match("ALT$") then
    isMod = true
    modName = "ALT"
  elseif keycode:match("META$") then
    isMod = true
    modName = "META"
  end

  if value == 1 then -- Press
    if keycode == "CAPSLOCK" then
      capsLockOn = not capsLockOn
    end

    if isMod then
      if modName == "SHIFT" then shiftHeld = true end
      if modName == "CTRL" then ctrlHeld = true end
      if modName == "ALT" then altHeld = true end
      if modName == "META" then metaHeld = true end
      comboEmitted = false
    else
      comboEmitted = true
    end
    return
  end

  if value == 0 then -- Release
    if isMod then
      local emitStandalone = not comboEmitted

      if modName == "SHIFT" then shiftHeld = false end
      if modName == "CTRL" then ctrlHeld = false end
      if modName == "ALT" then altHeld = false end
      if modName == "META" then metaHeld = false end

      if emitStandalone then
        local mLabel = ""
        if modName == "SHIFT" then mLabel = "SHIFT" end
        if modName == "CTRL" then mLabel = "CTRL" end
        if modName == "ALT" then mLabel = "ALT" end
        if modName == "META" then mLabel = "󰴈" end

        local mDisplay = getModPrefix() .. mLabel
        emitDisplay(mDisplay)
        comboEmitted = true
      end
      return
    end

    local label = getKeyLabel(keycode)
    if label == "" then return end

    local p = getModPrefix()
    if shiftHeld and not isShiftConsumed(keycode) then
      p ..= "SHIFT+"
    end

    emitDisplay(p .. label)
  end
end

local function stopStream()
  if isStreamRunning then
    if activeDevice then
      noctalia.runAsync(`pkill -f 'evtest {activeDevice}'`)
    end
    isStreamRunning = false
    activeDevice = nil
  end
end

local function startStream(device)
  stopStream()
  activeDevice = device
  isStreamRunning = true
  
  noctalia.runStream(`evtest '{device}'`, function(line)
    handleLine(line)
  end)
end

function update()
  local enabled = noctalia.getConfig("capture_enabled") ~= false
  local device = noctalia.getConfig("evtest_device") or "/dev/input/event3"

  -- If settings changed or capture toggled, apply changes
  if enabled ~= lastEnabled or device ~= lastDevice then
    lastEnabled = enabled
    lastDevice = device
    stopStream()
    startAttempts = 0
  end

  if enabled then
    -- Check if evtest is currently running (monitored by processMatches)
    noctalia.processMatches(function(matched)
      local now = os.clock()
      if not matched and not isStreamRunning then
        -- Cooldown attempt to start evtest if it crashed or failed
        if startAttempts < 3 and (now - lastAttemptTime > 10) then
          startAttempts += 1
          lastAttemptTime = now
          
          -- Check device readability before running
          noctalia.runAsync(`test -r '{device}'`, function(res)
            if res.exitCode == 0 then
              startStream(device)
            else
              noctalia.notify(
                noctalia.tr("error.title"),
                noctalia.tr("error.device_access")
              )
              stopStream()
            end
          end)
        end
      elseif matched then
        isStreamRunning = true
      end
    end, "evtest", device)
  else
    stopStream()
  end

  -- Auto-hide logic
  local hideDelay = noctalia.getConfig("hide_delay_sec") or 2
  if isOsdVisible and (os.clock() - lastEventTime > hideDelay) then
    isOsdVisible = false
    keyList = {}
    noctalia.state.set("keys", {})
  end
end
