-- Custom Commands — launcher provider.

local function getCommands()
  local jsonStr = noctalia.getConfig("commandsJson") or ""
  if jsonStr == "" then
    jsonStr = '[{"name":"File Manager","command":"xdg-open ~","icon":"folder"},{"name":"System Monitor","command":"gnome-system-monitor || plasma-systemmonitor || xfce4-taskmanager","icon":"activity"}]'
  end

  local ok, list = pcall(noctalia.json.decode, jsonStr)
  if not ok or type(list) ~= "table" then
    noctalia.log("Custom Commands: Failed to parse commandsJson")
    return {}
  end

  local valid = {}
  for _, item in list do
    if type(item) == "table" and item.command and item.command ~= "" then
      table.insert(valid, {
        name = item.name or "",
        command = item.command,
        icon = item.icon or "terminal-2"
      })
    end
  end
  return valid
end

function onQuery(query)
  local cmds = getCommands()
  local results = {}

  if query == "" then
    for _, cmd in cmds do
      table.insert(results, {
        id = cmd.command,
        title = cmd.name,
        subtitle = cmd.command,
        glyph = cmd.icon
      })
    end
  else
    local q = query:lower()
    for _, cmd in cmds do
      if (cmd.name and cmd.name:lower():find(q, 1, true)) or (cmd.command and cmd.command:lower():find(q, 1, true)) then
        table.insert(results, {
          id = cmd.command,
          title = cmd.name,
          subtitle = cmd.command,
          glyph = cmd.icon
        })
      end
    end
  end

  launcher.setResults(query, results)
end

function onActivate(command)
  noctalia.runAsync(command)
  launcher.close()
end
