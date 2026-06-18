-- Update Count — background service.
-- Periodically checks for system updates using pacman, yay, dnf, xbps, etc.

local updaters = {
  {
    name = "yay",
    cmdCheck = "command -v checkupdates >/dev/null 2>&1 && command -v yay >/dev/null 2>&1",
    cmdGetNumUpdates = "(checkupdates 2>/dev/null; yay -Qua 2>/dev/null) | wc -l",
    cmdDoSystemUpdate = "yay -Syu"
  },
  {
    name = "paru",
    cmdCheck = "command -v checkupdates >/dev/null 2>&1 && command -v paru >/dev/null 2>&1",
    cmdGetNumUpdates = "(checkupdates 2>/dev/null; paru -Qua 2>/dev/null) | wc -l",
    cmdDoSystemUpdate = "paru -Syu"
  },
  {
    name = "pacman",
    cmdCheck = "command -v pacman >/dev/null 2>&1",
    cmdGetNumUpdates = "pacman -Quq 2>/dev/null | wc -l",
    cmdDoSystemUpdate = "sudo pacman -Syu"
  },
  {
    name = "dnf",
    cmdCheck = "command -v dnf >/dev/null 2>&1",
    cmdGetNumUpdates = "dnf check-update -q | grep -c ^[a-z0-9]",
    cmdDoSystemUpdate = "sudo dnf upgrade"
  },
  {
    name = "xbps",
    cmdCheck = "command -v xbps-install >/dev/null 2>&1",
    cmdGetNumUpdates = "xbps-install -Mnu 2>&1 | grep -v '^$' | wc -l",
    cmdDoSystemUpdate = "sudo xbps-install -Su"
  }
}

local checkIndex = 1
local detectedUpdater = nil
local lastFetchTime = 0
local refreshing = false
local currentUpdateCount = 0

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function checkNext(callback)
  if checkIndex > #updaters then
    if callback then callback() end
    return
  end
  local current = updaters[checkIndex]
  checkIndex = checkIndex + 1
  noctalia.runAsync(current.cmdCheck, function(res)
    if res.exitCode == 0 then
      detectedUpdater = current
      if callback then callback() end
    else
      checkNext(callback)
    end
  end)
end

local function getNumUpdates()
  if refreshing then return end
  refreshing = true
  noctalia.state.set("refreshing", true)

  local customGet = noctalia.getConfig("customCmdGetNumUpdates") or ""
  local cmd = ""
  if customGet ~= "" then
    cmd = customGet
  elseif detectedUpdater then
    cmd = detectedUpdater.cmdGetNumUpdates
  else
    cmd = "exit 1"
  end

  noctalia.runAsync(cmd, function(res)
    local count = -1
    if res.exitCode == 0 then
      local stdout = trim(res.stdout or res.body or "")
      count = tonumber(stdout) or -1
    end
    
    if count >= 0 then
      currentUpdateCount = count
      noctalia.state.set("updateCount", count)
    else
      noctalia.state.set("updateCount", -1)
    end
    refreshing = false
    noctalia.state.set("refreshing", false)
  end)
end

local function doSystemUpdate()
  local customDo = noctalia.getConfig("customCmdDoSystemUpdate") or ""
  local updateCmd = ""
  if customDo ~= "" then
    updateCmd = customDo
  elseif detectedUpdater then
    updateCmd = detectedUpdater.cmdDoSystemUpdate
  else
    updateCmd = "echo 'No update cmd found.'"
  end

  local pluginId = "bukomoon/update-count"
  local ipcCmd = "noctalia msg plugin " .. pluginId .. " check"
  local combinedCmd = updateCmd .. " && " .. ipcCmd

  local term = noctalia.getConfig("updateTerminalCommand") or "foot -e"
  term = trim(term)
  local fullCmd
  if term:find("{}", 1, true) then
    fullCmd = term:gsub("{}", combinedCmd)
  else
    fullCmd = term .. " " .. combinedCmd
  end

  noctalia.runAsync(fullCmd)
end

local function poll()
  local now = os.time()
  local intervalMins = noctalia.getConfig("updateIntervalMinutes") or 30
  local refreshInterval = intervalMins * 60

  if lastFetchTime == 0 or (now - lastFetchTime >= refreshInterval) then
    lastFetchTime = now
    getNumUpdates()
  end
end

-- Initialize updater detection
checkNext(function()
  getNumUpdates()
end)

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    lastFetchTime = os.time()
    getNumUpdates()
  elseif cmd == "update" then
    doSystemUpdate()
  end
end)

function onIpc(event, arg1, arg2)
  if event == "check" then
    getNumUpdates()
  elseif event == "run" then
    doSystemUpdate()
  end
end

noctalia.setUpdateInterval(5000)

function onUpdate()
  poll()
end
