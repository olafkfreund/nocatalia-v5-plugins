-- Desktop Calendar — desktop widget.

local function getDaysInMonth(month, year)
  local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if month == 2 then
    if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
      return 29
    end
  end
  return days[month]
end

local function getMonthName(month)
  local names = {
    "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
    "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
  }
  return names[month] or "UNKNOWN"
end

local function render()
  local now = os.date("*t")
  local year = now.year
  local month = now.month
  local today = now.day

  -- Day of week of the 1st of the month
  -- Lua's os.time returns epoch. We set it to 12:00 to avoid timezone/DST shifts
  local firstTime = os.time({ year = year, month = month, day = 1, hour = 12 })
  local firstWday = os.date("*t", firstTime).wday -- 1 = Sunday, 2 = Monday, ..., 7 = Saturday

  -- Monday start: Sunday=6, Monday=0, Tuesday=1, etc.
  local firstDayOffset = (firstWday == 1) and 6 or (firstWday - 2)
  local totalDays = getDaysInMonth(month, year)

  -- Headers
  local headers = {"MO", "TU", "WE", "TH", "FR", "SA", "SU"}
  local headerRow = {}
  for _, h in headers do
    table.insert(headerRow, ui.label({
      text = h,
      fontSize = 11,
      fontWeight = "bold",
      color = "primary",
      align = "center"
    }))
  end

  -- Grid cells
  local cells = {}
  for i = 1, firstDayOffset do
    table.insert(cells, "")
  end
  for i = 1, totalDays do
    table.insert(cells, tostring(i))
  end
  while #cells < 42 do
    table.insert(cells, "")
  end

  -- Partition into weeks
  local gridRows = {
    ui.row({ gap = 12, align = "center" }, headerRow)
  }

  for w = 0, 5 do
    local weekRow = {}
    for d = 1, 7 do
      local val = cells[w * 7 + d]
      if val == "" then
        table.insert(weekRow, ui.label({ text = "  ", fontSize = 11, color = "on_surface_variant" }))
      else
        local isToday = (tonumber(val) == today)
        table.insert(weekRow, ui.button({
          text = val,
          variant = if isToday then "primary" else "flat",
          -- Flat/unclickable button or plain label:
          -- We use a button to make it look capped and nice
        }))
      end
    end
    table.insert(gridRows, ui.row({ gap = 12, align = "center" }, weekRow))
  end

  -- Main Layout
  local title = `{getMonthName(month)} {year}`
  desktopWidget.render(ui.column({ gap = 10, align = "center" }, {
    ui.label({
      text = title,
      fontSize = 15,
      fontWeight = "bold",
      color = "primary"
    }),
    ui.column({ gap = 6, align = "center" }, gridRows)
  }))
end

function update()
  -- Refresh every 60 seconds (1 minute) to check if date changed
  noctalia.setUpdateInterval(60000)
  render()
end
