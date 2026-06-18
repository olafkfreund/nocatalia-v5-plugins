-- Weekly Calendar — background service.
-- Provides current date and week information.

local today = ""
local weekday = ""
local weekNum = ""

local function updateState()
  noctalia.state.set("today", today)
  noctalia.state.set("weekday", weekday)
  noctalia.state.set("weekNum", weekNum)
end

local function refresh()
  noctalia.runAsync("date '+%Y-%m-%d|%A|%V' 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local text = (res.stdout or res.body or ""):gsub("\n", "")
      local date, day, week = text:match("^([^|]+)|([^|]+)|(.+)$")
      today = date or ""
      weekday = day or ""
      weekNum = week or ""
      updateState()
    end
  end)
end

refresh()

noctalia.setUpdateInterval(60000)

function onUpdate()
  refresh()
end
