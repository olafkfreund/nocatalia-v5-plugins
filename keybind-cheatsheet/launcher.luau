-- Keybind Cheatsheet — launcher provider.
-- Searches and filters compositor shortcuts.

local binds = {}

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  for _, b in binds do
    local desc = b.desc or ""
    local key = b.keybind or ""
    local cat = b.category or "General"

    if filter == "" or desc:lower():find(filter) or key:lower():find(filter) or cat:lower():find(filter) then
      table.insert(results, {
        id = key,
        title = desc,
        subtitle = `[{cat}]  {key}  (Press Enter to copy)`,
        glyph = "keyboard",
      })
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "empty",
      title = "No shortcuts found",
      subtitle = "No keybindings matched your query.",
      glyph = "alert-circle",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id ~= "" and id ~= "empty" then
    noctalia.copyToClipboard(id, "text/plain")
    noctalia.notify("Keybind Cheatsheet", `Copied to clipboard: {id}`)
  end
end

noctalia.state.watch("cheatsheet_data", function(val)
  binds = if type(val) == "table" then val else {}
end)
