-- Timer — background service.
-- Manages stopwatch and countdown states globally.

noctalia.setUpdateInterval(1000) -- Tick every second

-- States in noctalia.state:
--   timer_mode: "countdown" | "stopwatch"
--   timer_running: bool
--   timer_remaining: number
--   timer_elapsed: number
--   timer_total: number

local mode = noctalia.state.get("timer_mode") or "countdown"
local running = noctalia.state.get("timer_running") == true
local remaining = tonumber(noctalia.state.get("timer_remaining")) or 300
local elapsed = tonumber(noctalia.state.get("timer_elapsed")) or 0
local _total = tonumber(noctalia.state.get("timer_total")) or 300

function update()
  -- Read latest state modifications
  mode = noctalia.state.get("timer_mode") or "countdown"
  running = noctalia.state.get("timer_running") == true
  remaining = tonumber(noctalia.state.get("timer_remaining")) or 300
  elapsed = tonumber(noctalia.state.get("timer_elapsed")) or 0
  _total = tonumber(noctalia.state.get("timer_total")) or 300

  if running then
    if mode == "countdown" then
      if remaining > 0 then
        remaining -= 1
        noctalia.state.set("timer_remaining", remaining)
        if remaining == 0 then
          noctalia.state.set("timer_running", false)
          noctalia.notify("Timer", "Time's up!")
        end
      end
    else
      elapsed += 1
      noctalia.state.set("timer_elapsed", elapsed)
    end
  end
end
