-- Khal Agenda Info — desktop widget.

local calendarVal = nil
local isFetching = false

local function render()
  local rows = {}

  local headingText = noctalia.tr("widget.heading") or "Upcoming events"
  local buttonText = noctalia.tr("widget.button") or "📅"

  -- Title row
  table.insert(rows, ui.row({ gap = 8, align = "center" }, {
    ui.label({
      text = headingText,
      fontSize = 14,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.button({
      text = buttonText,
      variant = "flat",
      onClick = "runIkhal"
    })
  }))

  -- Content
  if calendarVal == nil then
    table.insert(rows, ui.label({
      text = noctalia.tr("widget.loading") or "Loading...",
      fontSize = 12,
      color = "on_surface_variant"
    }))
  elseif calendarVal == "" then
    table.insert(rows, ui.label({
      text = noctalia.tr("widget.no_events") or "No upcoming events",
      fontSize = 12,
      color = "on_surface_variant"
    }))
  else
    for line in string.gmatch(calendarVal, "[^\r\n]+") do
      -- Identify day headers like "Friday, 2026-06-19" using day-format '{name}, {date}'
      local isHeader = not string.match(line, "^%s") and string.find(line, ",")
      if isHeader then
        table.insert(rows, ui.label({
          text = line,
          fontSize = 12,
          fontWeight = "bold",
          color = "secondary"
        }))
      else
        table.insert(rows, ui.label({
          text = line,
          fontSize = 12,
          color = "on_surface"
        }))
      end
    end
  end

  desktopWidget.render(ui.column({ gap = 8, padding = 16 }, rows))
end

local function fetchCalendar()
  if isFetching then return end
  isFetching = true

  local cmd = "khal list --notstarted now 7d --format '{start-time} {title}' --day-format '{name}, {date}'"
  noctalia.runAsync(cmd, function(res)
    isFetching = false
    if res.exitCode == 0 then
      local val = res.stdout or ""
      val = val:gsub("^%s+", ""):gsub("%s+$", "")
      val = val:gsub("\n%s*\n", "\n")
      calendarVal = val
    else
      calendarVal = ""
    end
    render()
  end)
end

function runIkhal()
  local cmd = "for term in xdg-terminal-exec kitty alacritty foot gnome-terminal konsole st xterm; do " ..
              "if command -v $term >/dev/null 2>&1; then " ..
              "if [ \"$term\" = \"kitty\" ]; then " ..
              "exec kitty --class khal -e ikhal; " ..
              "else " ..
              "exec $term -e ikhal 2>/dev/null || exec $term -- ikhal; " ..
              "fi; break; fi; done"
  noctalia.runAsync(`sh -c '{cmd}'`)
end

function update()
  -- Refresh every 60 seconds (1 minute)
  noctalia.setUpdateInterval(60000)
  fetchCalendar()
end

-- Perform initial render
render()
