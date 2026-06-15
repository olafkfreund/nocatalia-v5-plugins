-- Keybind Cheatsheet — background service.
-- Detects compositor, parses configuration, and publishes cheatsheet data.

noctalia.setUpdateInterval(5000) -- Check settings & process every 5 seconds

local lastCompositor = nil
local lastParsedTime = 0
local parsedBinds = {}

local keyMap = {
  XF86AUDIORAISEVOLUME = "Vol Up",
  XF86AUDIOLOWERVOLUME = "Vol Down",
  XF86AUDIOMUTE = "Mute",
  XF86AUDIOMICMUTE = "Mic Mute",
  XF86AUDIOPLAY = "Play",
  XF86AUDIOPAUSE = "Pause",
  XF86AUDIONEXT = "Next",
  XF86AUDIOPREV = "Prev",
  XF86AUDIOSTOP = "Stop",
  XF86AUDIOMEDIA = "Media",
  XF86AudioRaiseVolume = "Vol Up",
  XF86AudioLowerVolume = "Vol Down",
  XF86AudioMute = "Mute",
  XF86AudioMicMute = "Mic Mute",
  XF86AudioPlay = "Play",
  XF86AudioPause = "Pause",
  XF86AudioNext = "Next",
  XF86AudioPrev = "Prev",
  XF86AudioStop = "Stop",
  XF86AudioMedia = "Media",
  XF86MONBRIGHTNESSUP = "Bright Up",
  XF86MONBRIGHTNESSDOWN = "Bright Down",
  XF86MonBrightnessUp = "Bright Up",
  XF86MonBrightnessDown = "Bright Down",
  XF86CALCULATOR = "Calc",
  XF86MAIL = "Mail",
  XF86SEARCH = "Search",
  XF86EXPLORER = "Files",
  XF86WWW = "Browser",
  XF86HOMEPAGE = "Home",
  XF86FAVORITES = "Favorites",
  XF86POWEROFF = "Power",
  XF86SLEEP = "Sleep",
  XF86EJECT = "Eject",
  PRINT = "PrtSc",
  Print = "PrtSc",
  PRIOR = "PgUp",
  NEXT = "PgDn",
  Prior = "PgUp",
  Next = "PgDn",
  MOUSE_DOWN = "Scroll Down",
  MOUSE_UP = "Scroll Up",
  ["MOUSE:272"] = "Left Click",
  ["MOUSE:273"] = "Right Click",
  ["MOUSE:274"] = "Middle Click"
}

local function formatSpecialKey(key)
  return keyMap[key] or key
end

local function splitLines(text)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

local function parseHyprland(text)
  local binds = {}
  local lines = splitLines(text)
  local currentCategory = "General"

  for _, line in lines do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    
    local catName = trimmed:match("^#%s*%d+%.%s*(.+)$")
    if catName then
      currentCategory = catName
    elseif trimmed:match("^bind[a-z]*%s*=") then
      local desc = trimmed:match('#"([^"]+)"%s*$') or ""
      local cleanLine = trimmed:gsub('%s*#"[^"]+"%s*$', "")
      local rhs = cleanLine:match("^bind[a-z]*%s*=%s*(.+)$")
      if rhs then
        local parts = {}
        for part in rhs:gmatch("[^,]+") do
          table.insert(parts, part:gsub("^%s+", ""):gsub("%s+$", ""))
        end
        
        if #parts >= 2 then
          local modsPart = parts[1]:upper()
          local keyPart = parts[2]
          local action = parts[3] or ""
          local arg = parts[4] or ""

          local mods = {}
          if modsPart:find("SUPER") or modsPart:find("MOD") then table.insert(mods, "Super") end
          if modsPart:find("CTRL") or modsPart:find("CONTROL") then table.insert(mods, "Ctrl") end
          if modsPart:find("ALT") then table.insert(mods, "Alt") end
          if modsPart:find("SHIFT") then table.insert(mods, "Shift") end

          local formattedKey = formatSpecialKey(keyPart)
          local keyDisplay = formattedKey
          if #mods > 0 then
            keyDisplay = table.concat(mods, " + ") .. " + " .. formattedKey
          end

          if desc == "" then
            desc = action
            if arg ~= "" then
              desc ..= " " .. arg
            end
          end

          table.insert(binds, {
            category = currentCategory,
            keybind = keyDisplay,
            desc = desc
          })
        end
      end
    end
  end
  return binds
end

local function parseNiri(text)
  local binds = {}
  local lines = splitLines(text)
  local currentCategory = "General"
  local inBinds = false
  local activeKey = nil
  local activeAction = ""

  for _, line in lines do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed:sub(1, 2) == "//" then
      local catName = trimmed:match('^//%s*"?([^"]+)"?')
      if catName then
        currentCategory = catName
      end
    elseif trimmed:find("^binds%s*{") then
      inBinds = true
    elseif inBinds then
      if trimmed == "}" then
        inBinds = false
      elseif trimmed ~= "" then
        local key, action = trimmed:match('^"?([%w%+%-_]+)"?%s+{%s*([^}]+);?%s*}')
        if key and action then
          action = action:gsub('spawn%s*"([^"]+)"', "%1"):gsub('spawn%-sh%s*"([^"]+)"', "%1")
          local formattedKey = formatSpecialKey(key)
          table.insert(binds, {
            category = currentCategory,
            keybind = formattedKey:gsub("Mod", "Super"),
            desc = action
          })
        else
          local keyStart = trimmed:match('^"?([%w%+%-_]+)"?%s+{%s*$')
          if keyStart then
            activeKey = keyStart
            activeAction = ""
          elseif activeKey then
            if trimmed == "}" then
              table.insert(binds, {
                category = currentCategory,
                keybind = formatSpecialKey(activeKey):gsub("Mod", "Super"),
                desc = activeAction:gsub("^%s+", ""):gsub("%s+$", "")
              })
              activeKey = nil
            else
              local act = trimmed:gsub(';%s*$', ""):gsub('spawn%s*"([^"]+)"', "%1"):gsub('spawn%-sh%s*"([^"]+)"', "%1")
              activeAction = activeAction .. " " .. act
            end
          end
        end
      end
    end
  end
  return binds
end

local function parseMango(text)
  local binds = {}
  local lines = splitLines(text)
  local currentCategory = "General"

  for _, line in lines do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed:match("^#%s*Category:%s*(.+)$") then
      currentCategory = trimmed:match("^#%s*Category:%s*(.+)$")
    elseif trimmed:match("^keybind%s*=%s*(.+)$") then
      local rhs = trimmed:match("^keybind%s*=%s*(.+)$")
      local parts = {}
      for part in rhs:gmatch("[^,]+") do
        table.insert(parts, part:gsub("^%s+", ""):gsub("%s+$", ""))
      end

      if #parts >= 2 then
        local keyPart = parts[1]:gsub("Mod4", "Super")
        local action = parts[2]
        local arg = parts[3] or ""

        local desc = action
        if arg ~= "" then
          desc ..= " " .. arg
        end

        local formattedKey = formatSpecialKey(keyPart)
        table.insert(binds, {
          category = currentCategory,
          keybind = formattedKey,
          desc = desc
        })
      end
    end
  end
  return binds
end

local function parseConfig(comp, text)
  if comp == "hyprland" then
    return parseHyprland(text)
  elseif comp == "niri" then
    return parseNiri(text)
  elseif comp == "mangowc" then
    return parseMango(text)
  end
  return {}
end

local function detectCompositor(callback)
  noctalia.runAsync("pgrep -x niri", function(res)
    if res.exitCode == 0 then
      callback("niri")
      return
    end
    noctalia.runAsync("pgrep -x hyprland", function(res2)
      if res2.exitCode == 0 then
        callback("hyprland")
        return
      end
      noctalia.runAsync("pgrep -x mangowc", function(res3)
        if res3.exitCode == 0 then
          callback("mangowc")
        else
          callback("unknown")
        end
      end)
    end)
  end)
end

function update()
  local now = os.clock()
  
  detectCompositor(function(comp)
    if comp == "unknown" then return end
    
    local pathSetting = ""
    if comp == "hyprland" then
      pathSetting = noctalia.getConfig("hyprland_config_path") or "~/.config/hypr/hyprland.conf"
    elseif comp == "niri" then
      pathSetting = noctalia.getConfig("niri_config_path") or "~/.config/niri/config.kdl"
    elseif comp == "mangowc" then
      pathSetting = noctalia.getConfig("mango_config_path") or "~/.config/mango/config.conf"
    end
    
    if comp ~= lastCompositor or (now - lastParsedTime >= 60) then
      lastCompositor = comp
      lastParsedTime = now
      
      local expandedPath = noctalia.expandPath(pathSetting)
      noctalia.runAsync(`cat '{expandedPath}'`, function(res)
        if res.exitCode == 0 then
          local binds = parseConfig(comp, res.stdout)
          parsedBinds = binds
          noctalia.state.set("cheatsheet_data", binds)
          noctalia.state.set("compositor", comp)
        else
          noctalia.log(`Keybind Cheatsheet: failed to read config at {expandedPath}`)
        end
      end)
    end
  end)
end
