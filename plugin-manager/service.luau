-- Plugin Manager — background service.
-- Provides access to installed plugin information.

local pluginCount = 0

local function updateState()
  noctalia.state.set("pluginCount", pluginCount)
end

local function countPlugins()
  noctalia.runAsync("find ~/.local/share/noctalia/plugins ~/.config/noctalia/plugins -name 'plugin.toml' 2>/dev/null | wc -l", function(res)
    pluginCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
    updateState()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    countPlugins()
  end
end)

countPlugins()

noctalia.setUpdateInterval(0)
