-- Arch Updater — background service.
-- Periodically checks for System, AUR, and Flatpak updates.

noctalia.setUpdateInterval(5000) -- Check check-interval every 5 seconds

local lastFetchTime = 0
local refreshing = false
local updates = {}
local noctaliaUpdate = false

local function parsePacmanLike(stdout, source)
  local list = {}
  for line in stdout:gmatch("[^\r\n]+") do
    local parts = {}
    for part in line:gmatch("%S+") do
      table.insert(parts, part)
    end
    -- Expected: name oldver -> newver (or >= 4 parts)
    if #parts >= 4 then
      table.insert(list, {
        id = parts[1],
        name = parts[1],
        oldVer = parts[2],
        newVer = parts[4],
        source = source
      })
    end
  end
  return list
end

local function parseFlatpak(stdout)
  local list = {}
  for line in stdout:gmatch("[^\r\n]+") do
    local parts = {}
    for part in line:gmatch("[^\t]+") do
      table.insert(parts, part)
    end
    -- Expected: application\tname\tnewver\toldver
    if #parts >= 4 then
      table.insert(list, {
        id = parts[1],
        name = parts[2],
        oldVer = parts[4],
        newVer = parts[3],
        source = "flatpak"
      })
    end
  end
  return list
end

local function checkNoctalia(list)
  local noctaliaNames = { "noctalia-qs", "noctalia-shell" }
  for _, item in list do
    for _, name in noctaliaNames do
      if item.name:find(name, 1, true) then
        return true
      end
    end
  end
  return false
end

local function checkUpdates()
  if refreshing then return end
  refreshing = true
  noctalia.state.set("refreshing", true)
  
  local systemCmd = noctalia.getConfig("systemCmd") or "checkupdates 2>/dev/null"
  local aurCmd = noctalia.getConfig("aurCmd") or "paru -Qua 2>/dev/null"
  local flatpakEnabled = noctalia.getConfig("flatpak") ~= false

  local newUpdates = {}

  -- 1. Check System
  noctalia.runAsync(systemCmd, function(res)
    if res.exitCode == 0 or res.exitCode == 1 then -- checkupdates exits with 1 if no updates
      local sysList = parsePacmanLike(res.stdout, "system")
      for _, item in sysList do table.insert(newUpdates, item) end
    end

    -- 2. Check AUR
    noctalia.runAsync(aurCmd, function(aurRes)
      if aurRes.exitCode == 0 or aurRes.exitCode == 1 then
        local aurList = parsePacmanLike(aurRes.stdout, "aur")
        for _, item in aurList do table.insert(newUpdates, item) end
      end

      -- 3. Check Flatpak
      if flatpakEnabled then
        local flatpakCmd = "flatpak update --no-deploy --noninteractive >/dev/null 2>&1; join -t'\t' -j1 <(flatpak remote-ls --updates --columns=application,name,version 2>/dev/null | sort -t'\t' -k1,1) <(flatpak list --columns=application,version 2>/dev/null | sort -t'\t' -k1,1)"
        noctalia.runAsync(flatpakCmd, function(flatRes)
          if flatRes.exitCode == 0 then
            local flatList = parseFlatpak(flatRes.stdout)
            for _, item in flatList do table.insert(newUpdates, item) end
          end

          updates = newUpdates
          noctaliaUpdate = checkNoctalia(updates)
          noctalia.state.set("updates", updates)
          noctalia.state.set("noctalia_update", noctaliaUpdate)
          refreshing = false
          noctalia.state.set("refreshing", false)
        end)
      else
        updates = newUpdates
        noctaliaUpdate = checkNoctalia(updates)
        noctalia.state.set("updates", updates)
        noctalia.state.set("noctalia_update", noctaliaUpdate)
        refreshing = false
        noctalia.state.set("refreshing", false)
      end
    end)
  end)
end

local function poll()
  local now = os.clock()
  local intervalMins = noctalia.getConfig("refreshInterval") or 120
  local refreshInterval = intervalMins * 60

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    checkUpdates()
  end
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    lastFetchTime = 0
    poll()
  elseif cmd == "update" then
    local updateCmd = noctalia.getConfig("updateCmd") or "ghostty -e bash -c 'echo \"Updating System...\";paru; flatpak update; read -n 1 -p \"Press any key to exit...\"'"
    noctalia.runInTerminal(updateCmd)
    lastFetchTime = 0
  end
end)

function update()
  poll()
end
