-- Slowbongo — background service.
-- Detects music playback and animates a bongo cat in the bar.

local isPlaying = false
local bpmEstimate = 120
local frame = 0

local function updateState()
  noctalia.state.set("isPlaying", isPlaying)
  noctalia.state.set("bpm", bpmEstimate)
  noctalia.state.set("frame", frame)
end

local function checkMusic()
  noctalia.runAsync("playerctl status 2>/dev/null", function(res)
    local status = (res.stdout or res.body or ""):gsub("\n", "")
    local wasPlaying = isPlaying
    isPlaying = status == "Playing"
    if isPlaying then
      frame = (frame % 4) + 1
    else
      frame = 0
    end
    updateState()
  end)
end

checkMusic()

local idleTimeout = tonumber(noctalia.getConfig("idleTimeout")) or 5000
-- Update frequently for animation
noctalia.setUpdateInterval(math.max(100, math.floor(60000 / (bpmEstimate * 2))))

function onUpdate()
  checkMusic()
end
