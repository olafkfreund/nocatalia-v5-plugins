-- Polkit Agent — background service.
-- Monitors polkit agent status.

local agentRunning = false

local function updateState()
  noctalia.state.set("agentRunning", agentRunning)
end

local function checkAgent()
  noctalia.runAsync("pgrep -x polkit-agent 2>/dev/null || pgrep -f 'polkit-gnome-authentication-agent' 2>/dev/null || pgrep -f 'lxpolkit' 2>/dev/null || pgrep -f 'xfce-polkit' 2>/dev/null", function(res)
    agentRunning = res.exitCode == 0 and (res.stdout or res.body or ""):gsub("\n", "") ~= ""
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    checkAgent()
  end
end)

checkAgent()

noctalia.setUpdateInterval(10000)

function onUpdate()
  checkAgent()
end
