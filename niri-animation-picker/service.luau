-- Niri Animation Picker — background service.
-- Lists animation preset files and applies them to Niri config.

local animations = {}
local currentAnimation = ""

local function updateState()
  noctalia.state.set("animations", table.concat(animations, ","))
  noctalia.state.set("currentAnimation", currentAnimation)
  noctalia.state.set("animationCount", #animations)
end

local function listAnimations()
  local folder = noctalia.getConfig("animationsFolder") or ""
  if folder == "" then
    folder = os.getenv("HOME") .. "/.config/niri/animations"
  end

  noctalia.runAsync("ls -1 " .. folder .. " 2>/dev/null | grep -E '\\.(kdl|toml|conf)$' | sort", function(res)
    animations = {}
    if res.exitCode == 0 then
      for line in (res.stdout or res.body or ""):gmatch("[^\n]+") do
        if line ~= "" then
          animations[#animations + 1] = line:gsub("%.[^.]+$", "")
        end
      end
    end
    updateState()
  end)
end

local function applyAnimation(name)
  local folder = noctalia.getConfig("animationsFolder") or (os.getenv("HOME") .. "/.config/niri/animations")
  local target = noctalia.getConfig("targetFile") or (os.getenv("HOME") .. "/.config/niri/config.kdl")
  -- Find file with any extension
  noctalia.runAsync("ls " .. folder .. "/" .. name .. ".* 2>/dev/null | head -1", function(res)
    local file = (res.stdout or res.body or ""):gsub("\n", "")
    if file ~= "" then
      noctalia.runAsync("cp " .. file .. " " .. target .. " 2>/dev/null && niri msg action reload 2>/dev/null", function(res2)
        currentAnimation = name
        updateState()
      end)
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    listAnimations()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "apply" then
      applyAnimation(arg)
    end
  end
end)

listAnimations()

noctalia.setUpdateInterval(0)
