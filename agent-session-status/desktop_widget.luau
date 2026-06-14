-- Agent Session Status — desktop widget.
-- Displays the list of active agents and their session details.

local agents = {}
local runningCount = 0
local serviceError = ""
local serviceRunning = false

local function render()
  local rows = {}

  -- Header
  local title = noctalia.tr("panel.title") or "Agent Sessions"
  local subtitlePattern = noctalia.tr("panel.subtitle") or "{count} running"
  local subtitle = string.gsub(subtitlePattern, "{count}", tostring(runningCount))
  -- Remove url placeholder if present
  subtitle = string.gsub(subtitle, "%s*-%s*{url}", "")

  table.insert(rows, ui.label({
    text = title,
    fontSize = 18,
    fontWeight = "bold",
    color = "primary"
  }))

  table.insert(rows, ui.label({
    text = subtitle,
    fontSize = 12,
    color = "on_surface_variant"
  }))

  -- Error message if service is down
  if serviceError ~= "" then
    table.insert(rows, ui.label({
      text = serviceError,
      fontSize = 12,
      color = "error"
    }))
  end

  -- Sessions List
  if #agents == 0 then
    local emptyText = noctalia.tr("panel.empty") or "No sessions reported"
    table.insert(rows, ui.label({
      text = emptyText,
      fontSize = 14,
      color = "on_surface_variant"
    }))
  else
    for _, group in agents do
      -- Agent Group Header
      table.insert(rows, ui.label({
        text = group.agent or "Agent",
        fontSize = 14,
        fontWeight = "semibold",
        color = "primary"
      }))

      -- Individual Sessions
      for _, sess in group.sessions or {} do
        local statusColor = "on_surface_variant"
        local statusGlyph = "○"
        
        if sess.status == "running" then
          statusColor = "primary"
          statusGlyph = "●"
        elseif sess.status == "blocked" then
          statusColor = "error"
          statusGlyph = "▲"
        elseif sess.status == "completed" then
          statusColor = "success"
          statusGlyph = "✓"
        end

        table.insert(rows, ui.row({ gap = 8, align = "center" }, {
          ui.label({ text = statusGlyph, color = statusColor, fontSize = 12 }),
          ui.label({ text = sess.title or sess.id, fontSize = 12, color = "on_surface" }),
          ui.label({ text = `[{sess.status}]`, fontSize = 10, color = "on_surface_variant" })
        }))
      end
    end
  end

  -- Action Buttons
  table.insert(rows, ui.row({ gap = 8 }, {
    ui.button({ text = "Refresh", variant = "outline", onClick = "refreshData" }),
    ui.button({ text = "Prune Inactive", variant = "outline", onClick = "pruneData" })
  }))

  desktopWidget.render(ui.column({ gap = 10, align = "left" }, rows))
end

function refreshData()
  noctalia.state.set("command", "refresh")
end

function pruneData()
  noctalia.state.set("command", "prune")
end

noctalia.state.watch("agents", function(val)
  agents = if type(val) == "table" then val else {}
  render()
end)

noctalia.state.watch("runningCount", function(val)
  runningCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("serviceError", function(val)
  serviceError = if type(val) == "string" then val else ""
  render()
end)

noctalia.state.watch("serviceRunning", function(val)
  serviceRunning = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
