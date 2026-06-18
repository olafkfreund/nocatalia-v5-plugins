-- ProtonVPN — background service.
-- Polls `protonvpn status` and exposes state to the bar widget.
-- Watches the "command" state key for toggle/connect/disconnect actions.

local pollIntervalMs = 5000
local isActing = false

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Extract the value of a field like "Status:  Connected" from status output.
local function extractField(text, fieldName)
  local pattern = fieldName .. ":%s*(.-)%s*\n"
  local val = text:match(pattern)
  if val == nil then
    -- Try end-of-string case (last line has no trailing newline).
    local endPattern = fieldName .. ":%s*(.-)%s*$"
    val = text:match(endPattern)
  end
  return val and trim(val) or ""
end

-- ── Status refresh ────────────────────────────────────────────────────────────

local function refreshStatus()
  noctalia.runAsync("protonvpn status", function(res)
    local text = res.stdout or ""
    local statusVal = extractField(text, "Status")
    local statusLower = statusVal:lower()

    if statusLower == "connected" then
      noctalia.state.set("connected", true)

      local server = extractField(text, "Server")
      -- Server line is like "CH#123  in  Zurich, Switzerland"
      local serverName = ""
      local serverLocation = ""
      local m1, m2 = server:match("^(%S+)%s+in%s+(.+)$")
      if m1 then
        serverName = m1
        serverLocation = trim(m2)
      else
        serverName = server
      end
      noctalia.state.set("serverName", serverName)
      noctalia.state.set("serverLocation", serverLocation)

      local ip = extractField(text, "IP")
      noctalia.state.set("ipAddress", ip)

      local proto = extractField(text, "Protocol")
      noctalia.state.set("protocol", proto)

      local loadVal = extractField(text, "Load")
      local loadNum = tonumber(loadVal) or -1
      noctalia.state.set("serverLoad", loadNum)
    else
      -- Disconnected or unknown.
      noctalia.state.set("connected", false)
      noctalia.state.set("serverName", "")
      noctalia.state.set("serverLocation", "")
      noctalia.state.set("ipAddress", "")
      noctalia.state.set("protocol", "")
      noctalia.state.set("serverLoad", -1)
    end

    isActing = false
    noctalia.state.set("acting", false)
  end)
end

-- ── Kill-switch refresh ───────────────────────────────────────────────────────

local function refreshKillSwitch()
  noctalia.runAsync("protonvpn config list", function(res)
    local text = res.stdout or ""
    local ks = "unknown"
    local match = text:match("kill%-switch%s+(%S+)")
    if match then
      ks = match:lower()
    end
    noctalia.state.set("killSwitch", ks)
  end)
end

-- ── Command watcher ───────────────────────────────────────────────────────────

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  if isActing then return end

  local action = cmd.action
  if type(action) ~= "string" then return end

  isActing = true
  noctalia.state.set("acting", true)

  if action == "connect" then
    noctalia.runAsync("protonvpn connect", function(res)
      if res.exitCode == 0 then
        noctalia.notify("ProtonVPN", noctalia.tr("toast.connected") or "ProtonVPN Connected")
      else
        noctalia.notifyError("ProtonVPN", noctalia.tr("toast.connect-failed") or "ProtonVPN connection failed")
      end
      refreshStatus()
    end)

  elseif action == "disconnect" then
    noctalia.runAsync("protonvpn disconnect", function(res)
      if res.exitCode == 0 then
        noctalia.notify("ProtonVPN", noctalia.tr("toast.disconnected") or "ProtonVPN Disconnected")
      end
      refreshStatus()
    end)

  elseif action == "connect-securecore" then
    noctalia.runAsync("protonvpn connect --securecore", function(res)
      if res.exitCode == 0 then
        noctalia.notify("ProtonVPN", noctalia.tr("toast.connected") or "ProtonVPN Connected (Secure Core)")
      else
        noctalia.notifyError("ProtonVPN", noctalia.tr("toast.connect-failed") or "ProtonVPN connection failed")
      end
      refreshStatus()
    end)

  elseif action == "connect-p2p" then
    noctalia.runAsync("protonvpn connect --p2p", function(res)
      if res.exitCode == 0 then
        noctalia.notify("ProtonVPN", noctalia.tr("toast.connected") or "ProtonVPN Connected (P2P)")
      else
        noctalia.notifyError("ProtonVPN", noctalia.tr("toast.connect-failed") or "ProtonVPN connection failed")
      end
      refreshStatus()
    end)

  elseif action == "set-killswitch" then
    local value = cmd.value
    if value ~= "off" and value ~= "standard" then
      isActing = false
      noctalia.state.set("acting", false)
      return
    end
    local cmdStr = "protonvpn config set kill-switch " .. value
    noctalia.runAsync(cmdStr, function()
      refreshStatus()
      refreshKillSwitch()
    end)

  elseif action == "toggle" then
    -- Read current connected state and toggle accordingly.
    local connectedNow = noctalia.state.get("connected")
    if connectedNow == true then
      noctalia.runAsync("protonvpn disconnect", function(res)
        if res.exitCode == 0 then
          noctalia.notify("ProtonVPN", noctalia.tr("toast.disconnected") or "ProtonVPN Disconnected")
        end
        refreshStatus()
      end)
    else
      noctalia.runAsync("protonvpn connect", function(res)
        if res.exitCode == 0 then
          noctalia.notify("ProtonVPN", noctalia.tr("toast.connected") or "ProtonVPN Connected")
        else
          noctalia.notifyError("ProtonVPN", noctalia.tr("toast.connect-failed") or "ProtonVPN connection failed")
        end
        refreshStatus()
      end)
    end

  elseif action == "refresh" then
    isActing = false
    noctalia.state.set("acting", false)
    refreshStatus()
    refreshKillSwitch()

  else
    -- Unknown action — release lock.
    isActing = false
    noctalia.state.set("acting", false)
  end
end)

-- ── Periodic update ──────────────────────────────────────────────────────────

function update()
  local cfg = noctalia.getConfig("pollInterval")
  local interval = tonumber(cfg) or pollIntervalMs
  noctalia.setUpdateInterval(interval)
  if not isActing then
    refreshStatus()
    refreshKillSwitch()
  end
end
