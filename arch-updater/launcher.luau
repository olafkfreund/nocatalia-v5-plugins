-- Arch Updater — launcher provider.
-- Lists updates and allows opening package info or performing updates.

local updates = {}

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  -- Command shortcuts
  if filter == "" then
    table.insert(results, {
      id = "cmd:update",
      title = "Update System",
      subtitle = "Run system upgrade command",
      glyph = "arrow-big-down-lines",
    })
    table.insert(results, {
      id = "cmd:refresh",
      title = "Refresh Updates",
      subtitle = "Check for updates now",
      glyph = "refresh",
    })
  end

  for _, item in updates do
    local name = item.name or ""
    local oldVer = item.oldVer or ""
    local newVer = item.newVer or ""
    local source = item.source or ""

    if filter == "" or name:lower():find(filter) or source:lower():find(filter) then
      local glyph = "package"
      if source == "system" then glyph = "brand-debian"
      elseif source == "aur" then glyph = "box"
      elseif source == "flatpak" then glyph = "archive"
      end

      table.insert(results, {
        id = `pkg:{source}:{item.id}`,
        title = name,
        subtitle = `[{source:upper()}]  {oldVer} ➔ {newVer}  (Press Enter to open info page)`,
        glyph = glyph,
      })
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "empty",
      title = "No updates found",
      subtitle = "No updates matched your query.",
      glyph = "alert-circle",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  if id == "cmd:update" then
    noctalia.state.set("command", "update")
  elseif id == "cmd:refresh" then
    noctalia.state.set("command", "refresh")
    noctalia.notify("Arch Updater", "Checking for updates...")
  elseif id:find("pkg:", 1, true) == 1 then
    local source, pkgId = id:match("^pkg:([^:]+):(.*)$")
    if source and pkgId then
      local url = ""
      if source == "system" then
        url = `https://archlinux.org/packages/?q={pkgId}`
      elseif source == "aur" then
        url = `https://aur.archlinux.org/packages/{pkgId}`
      elseif source == "flatpak" then
        url = `https://flathub.org/en/apps/{pkgId}`
      end
      if url ~= "" then
        noctalia.runAsync(`xdg-open '{url}'`)
      end
    end
  end
end

noctalia.state.watch("updates", function(val)
  updates = if type(val) == "table" then val else {}
end)
