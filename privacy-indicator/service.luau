-- Privacy Indicator — background service.
-- Detects which processes are using camera and microphone via /sys and /proc.

local cameraApps = ""
local micApps = ""
local cameraActive = false
local micActive = false

local function updateState()
  noctalia.state.set("cameraApps", cameraApps)
  noctalia.state.set("micApps", micApps)
  noctalia.state.set("cameraActive", cameraActive)
  noctalia.state.set("micActive", micActive)
end

local function checkCamera()
  local cmd = "for dev in /sys/class/video4linux/video*; do [ -e \"$dev/name\" ] && grep -qv 'Metadata' \"$dev/name\" && dev_name=$(basename \"$dev\") && find /proc/[0-9]*/fd -lname \"/dev/$dev_name\" 2>/dev/null; done | cut -d/ -f3 | xargs -r ps -o comm= -p 2>/dev/null | sort -u | tr '\\n' ',' | sed 's/,$//'"
  noctalia.runAsync("sh -c '" .. cmd .. "'", function(res)
    local apps = (res.stdout or res.body or ""):gsub("\n", ""):gsub(",$", "")
    cameraApps = apps
    cameraActive = apps ~= ""
    updateState()
  end)
end

local function checkMic()
  local cmd = "fuser /dev/snd/pcmC*c 2>/dev/null | tr ' ' '\\n' | xargs -r ps -o comm= -p 2>/dev/null | sort -u | tr '\\n' ',' | sed 's/,$//'"
  noctalia.runAsync("sh -c '" .. cmd .. "'", function(res)
    local apps = (res.stdout or res.body or ""):gsub("\n", ""):gsub(",$", "")
    micApps = apps
    micActive = apps ~= ""
    updateState()
  end)
end

local function refresh()
  checkCamera()
  checkMic()
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  end
end)

refresh()

noctalia.setUpdateInterval(2000)

function onUpdate()
  refresh()
end
