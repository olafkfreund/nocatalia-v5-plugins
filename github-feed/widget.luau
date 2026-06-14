-- GitHub Feed — bar widget.

local notificationCount = 0
local isLoading = false
local username = ""

local function render()
  barWidget.setGlyph("brand-github")
  if username == "" then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("GitHub Feed\nClick to configure")
    return
  end

  barWidget.setGlyphColor("on_surface")
  
  if notificationCount > 0 then
    barWidget.setText(tostring(notificationCount))
    barWidget.setGlyphColor("error")
  else
    barWidget.setText("")
  end

  local tooltip = `GitHub Feed - @{username}\n`
  if notificationCount > 0 then
    tooltip ..= `{notificationCount} unread notification(s)\n`
  end
  if isLoading then
    tooltip ..= "Loading..."
  else
    tooltip ..= "Click to open notifications\nRight-click to refresh"
  end
  barWidget.setTooltip(tooltip)
end

function onClick()
  if username == "" then
    noctalia.notify("GitHub Feed", "Please configure your GitHub username in settings.")
    return
  end
  
  -- Open notifications in browser
  local targetUrl = "https://github.com/notifications"
  local githubUrl = barWidget.getConfig("github_url") or ""
  if githubUrl ~= "" then
    local host = githubUrl:gsub("^https?://", ""):gsub("/+$", "")
    targetUrl = `https://{host}/notifications`
  end
  noctalia.runAsync(`xdg-open '{targetUrl}'`)
end

function onRightClick()
  noctalia.state.set("command", "refresh")
  noctalia.notify("GitHub Feed", "Refreshing feed...")
end

noctalia.state.watch("notification_count", function(val)
  notificationCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("is_loading", function(val)
  isLoading = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  username = barWidget.getConfig("username") or ""
  render()
end
