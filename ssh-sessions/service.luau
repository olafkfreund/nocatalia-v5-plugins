-- SSH Sessions — background service.
-- Periodically polls active SSH sessions and parses ~/.ssh/config.

local hostList = {}
local activeCount = 0
local sortedHosts = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(str, sep)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(str, sep, from, true)
  while delim_from do
    table.insert(result, string.sub(str, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(str, sep, from, true)
  end
  table.insert(result, string.sub(str, from))
  return result
end

-- ======== SSH config parsing ========
local function parseSshConfig(text)
  if not text or text == "" then
    hostList = {}
    return
  end

  local hosts = {}
  local current = nil

  for line in text:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" and line:sub(1, 1) ~= "#" then
      -- Host name
      if line:lower():match("^host%s+") then
        local hostName = line:gsub("^host%s+", ""):gsub("^Host%s+", "")
        hostName = trim(hostName)
        -- Skip wildcards
        if hostName ~= "*" and not hostName:find("*", 1, true) then
          current = {
            name = hostName,
            hostname = "",
            user = "",
            port = "",
            proxyJump = "",
            identityFile = ""
          }
          table.insert(hosts, current)
        else
          current = nil
        end
      elseif current then
        local key, val = line:match("^([%w_]+)%s+(.+)$")
        if key and val then
          key = key:lower()
          val = trim(val)
          if key == "hostname" then
            current.hostname = val
          elseif key == "user" then
            current.user = val
          elseif key == "port" then
            current.port = val
          elseif key == "proxyjump" then
            current.proxyJump = val
          elseif key == "identityfile" then
            current.identityFile = val
          end
        end
      end
    end
  end

  hostList = hosts
end

local function findMatchingHost(target)
  for _, host in ipairs(hostList) do
    if target == host.name then return host.name end
    if target == host.hostname then return host.name end
    if host.user ~= "" and target == host.user .. "@" .. host.hostname then return host.name end
    if host.user ~= "" and target == host.user .. "@" .. host.name then return host.name end
  end
  return ""
end

local function isHostActive(hostName, activeSessions)
  for _, s in ipairs(activeSessions) do
    if s.matchedHost == hostName then return true end
  end
  return false
end

local function updateSortedHosts(activeSessions)
  local showInactive = noctalia.getConfig("showInactiveHosts") ~= false
  local active = {}
  local inactive = {}
  local matchedNames = {}

  for _, host in ipairs(hostList) do
    if isHostActive(host.name, activeSessions) then
      table.insert(active, { host = host, isActive = true })
      matchedNames[host.name] = true
    elseif showInactive then
      table.insert(inactive, { host = host, isActive = false })
    end
  end

  for _, s in ipairs(activeSessions) do
    if s.matchedHost == "" and not matchedNames[s.target] then
      table.insert(active, {
        host = { name = s.target, hostname = "", user = "", port = "", proxyJump = "", identityFile = "" },
        isActive = true
      })
      matchedNames[s.target] = true
    end
  end

  -- Combine active and inactive
  local combined = {}
  for _, h in ipairs(active) do
    table.insert(combined, h)
  end
  for _, h in ipairs(inactive) do
    table.insert(combined, h)
  end

  sortedHosts = combined
  noctalia.state.set("hosts", sortedHosts)
  noctalia.state.set("activeCount", #active)

  local tooltip = ""
  if #activeSessions == 0 then
    tooltip = noctalia.tr("bar.noSessions") or "No active SSH sessions"
  elseif #activeSessions == 1 then
    tooltip = noctalia.tr("bar.oneSession") or "1 active SSH session"
  else
    tooltip = tostring(#activeSessions) .. " " .. (noctalia.tr("bar.multipleSessions") or "active SSH sessions")
  end

  if #activeSessions > 0 then
    tooltip = tooltip .. "\n───────────────"
    for _, s in ipairs(activeSessions) do
      tooltip = tooltip .. "\n" .. (s.matchedHost ~= "" and s.matchedHost or s.target)
    end
  end
  noctalia.state.set("tooltipText", tooltip)
end

local function refresh()
  local home = os.getenv("HOME") or "/tmp"
  local configPath = home .. "/.ssh/config"

  -- Read config file
  local content = noctalia.readFile(configPath) or ""
  parseSshConfig(content)

  -- Poll active ssh sessions
  noctalia.runAsync("pgrep -af 'ssh ' 2>/dev/null", function(res)
    local sessions = {}
    if res.exitCode == 0 then
      local stdout = res.stdout or res.body or ""
      for line in stdout:gmatch("[^\r\n]+") do
        line = trim(line)
        local isClient = true
        local excludes = { "sshd", "ssh-agent", "ssh-add", "ssh-keygen", "ssh-copy-id", "autossh", "pgrep", "-e ssh", " -W " }
        for _, pattern in ipairs(excludes) do
          if line:find(pattern, 1, true) then
            isClient = false
            break
          end
        end

        if isClient then
          local parts = split(line, " ")
          local sshIdx = -1
          for j, part in ipairs(parts) do
            if part == "ssh" or part:sub(-4) == "/ssh" then
              sshIdx = j
              break
            end
          end

          if sshIdx ~= -1 then
            local target = ""
            for k = #parts, sshIdx + 1, -1 do
              if parts[k]:sub(1, 1) ~= "-" then
                target = parts[k]
                break
              end
            end

            if target ~= "" then
              local matched = findMatchingHost(target)
              table.insert(sessions, {
                target = target,
                matchedHost = matched
              })
            end
          end
        end
      end
    end

    updateSortedHosts(sessions)
  end)
end

-- Command handler for IPC/actions
noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end

  if cmd.action == "refresh" then
    refresh()
  elseif cmd.action == "connect" then
    local hostName = cmd.hostName
    if hostName and hostName ~= "" then
      noctalia.runInTerminal("ssh " .. hostName)
    end
  elseif cmd.action == "toggle" then
    noctalia.runAsync("noctalia msg panel-toggle launcher \">ssh \"")
  end
end)

-- Initialize poll loop
local pollInterval = noctalia.getConfig("pollInterval") or 10
noctalia.setUpdateInterval(pollInterval * 1000)

function onUpdate()
  refresh()
end

-- Perform initial run
refresh()
