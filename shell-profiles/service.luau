-- Shell Profiles — background service.
-- Lists and applies shell profile configurations from a directory.

local profiles = {}
local currentProfile = ""

local function updateState()
  noctalia.state.set("profiles", table.concat(profiles, ","))
  noctalia.state.set("currentProfile", currentProfile)
  noctalia.state.set("profileCount", #profiles)
end

local function listProfiles()
  local profilesDir = noctalia.getConfig("profilesDir") or ""
  if profilesDir == "" then
    profilesDir = os.getenv("HOME") .. "/.config/shell-profiles"
  end

  noctalia.runAsync("ls -1 " .. profilesDir .. " 2>/dev/null | grep -v '^\\.' | sort", function(res)
    profiles = {}
    if res.exitCode == 0 then
      for line in (res.stdout or res.body or ""):gmatch("[^\n]+") do
        if line ~= "" then
          profiles[#profiles + 1] = line
        end
      end
    end
    updateState()
  end)
end

local function applyProfile(name)
  local profilesDir = noctalia.getConfig("profilesDir") or ""
  if profilesDir == "" then
    profilesDir = os.getenv("HOME") .. "/.config/shell-profiles"
  end
  local profilePath = profilesDir .. "/" .. name
  noctalia.runAsync("test -x " .. profilePath .. " && " .. profilePath .. " 2>/dev/null || sh " .. profilePath .. " 2>/dev/null", function(res)
    if res.exitCode == 0 then
      currentProfile = name
      updateState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    listProfiles()
  elseif cmd then
    local action, arg = cmd:match("^([^:]+):(.+)$")
    if action == "apply" then
      applyProfile(arg)
    end
  end
end)

currentProfile = noctalia.getConfig("lastAppliedProfile") or ""
listProfiles()

noctalia.setUpdateInterval(0)

function onUpdate()
  listProfiles()
end
