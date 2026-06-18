-- Tamagotchi — background service.
-- A virtual pet that lives in the bar.

local saveFile = os.getenv("HOME") .. "/.local/share/noctalia/tamagotchi.json"

local hunger = 50
local happiness = 70
local cleanliness = 80
local age = 0
local mood = "happy"
local isDead = false

local function updateState()
  noctalia.state.set("hunger", hunger)
  noctalia.state.set("happiness", happiness)
  noctalia.state.set("cleanliness", cleanliness)
  noctalia.state.set("age", age)
  noctalia.state.set("mood", mood)
  noctalia.state.set("isDead", isDead)
end

local function calcMood()
  if isDead then mood = "dead"; return end
  local avg = (happiness + (100 - hunger) + cleanliness) / 3
  if avg >= 80 then mood = "happy"
  elseif avg >= 60 then mood = "content"
  elseif avg >= 40 then mood = "bored"
  elseif avg >= 20 then mood = "sad"
  else mood = "critical"
  end
end

local function save()
  local json = string.format('{"hunger":%d,"happiness":%d,"cleanliness":%d,"age":%d}',
    hunger, happiness, cleanliness, age)
  noctalia.runAsync("echo '" .. json .. "' > " .. saveFile, function(res) end)
end

local function load()
  noctalia.runAsync("cat " .. saveFile .. " 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local text = res.stdout or res.body or ""
      hunger = tonumber(text:match('"hunger":(%d+)')) or hunger
      happiness = tonumber(text:match('"happiness":(%d+)')) or happiness
      cleanliness = tonumber(text:match('"cleanliness":(%d+)')) or cleanliness
      age = tonumber(text:match('"age":(%d+)')) or age
    else
      hunger = tonumber(noctalia.getConfig("hunger")) or 50
      happiness = tonumber(noctalia.getConfig("happiness")) or 70
      cleanliness = tonumber(noctalia.getConfig("cleanliness")) or 80
    end
    calcMood()
    updateState()
  end)
end

local function tick()
  if isDead then return end
  -- Degrade over time
  hunger = math.min(100, hunger + 2)
  happiness = math.max(0, happiness - 1)
  cleanliness = math.max(0, cleanliness - 1)
  age = age + 1
  -- Check for death
  if hunger >= 100 or happiness <= 0 then
    isDead = true
  end
  calcMood()
  updateState()
  save()
end

noctalia.state.watch("command", function(cmd)
  if cmd == "feed" then
    hunger = math.max(0, hunger - 30)
    calcMood()
    updateState()
    save()
  elseif cmd == "play" then
    happiness = math.min(100, happiness + 20)
    calcMood()
    updateState()
    save()
  elseif cmd == "clean" then
    cleanliness = math.min(100, cleanliness + 30)
    calcMood()
    updateState()
    save()
  elseif cmd == "revive" then
    isDead = false
    hunger = 50
    happiness = 70
    cleanliness = 80
    age = 0
    calcMood()
    updateState()
    save()
  end
end)

load()

-- Tick every 5 minutes
noctalia.setUpdateInterval(300000)

function onUpdate()
  tick()
end
