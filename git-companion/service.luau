-- Git Companion — background service.
-- Polls GitHub/GitLab for open PRs and issues using gh or glab CLI.

local prCount = 0
local issueCount = 0
local available = false
local platform = "github"
local errorMsg = ""

local function getBin()
  if platform == "gitlab" then
    return "glab"
  end
  return "gh"
end

local function updateState()
  noctalia.state.set("prCount", prCount)
  noctalia.state.set("issueCount", issueCount)
  noctalia.state.set("available", available)
  noctalia.state.set("platform", platform)
  noctalia.state.set("errorMsg", errorMsg)
end

local function buildRepoFlag()
  local repo = noctalia.getConfig("repo") or ""
  if repo ~= "" then
    return " -R " .. repo
  end
  local group = noctalia.getConfig("group") or ""
  if group ~= "" then
    if platform == "gitlab" then
      return " --group " .. group
    else
      return " --owner " .. group
    end
  end
  return ""
end

local function refresh()
  platform = noctalia.getConfig("platform") or "github"
  local bin = getBin()
  local repoFlag = buildRepoFlag()

  noctalia.runAsync(bin .. " --version 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      available = false
      errorMsg = bin .. " not installed"
      updateState()
      return
    end
    available = true
    errorMsg = ""
    updateState()
  end)

  -- Fetch PRs
  local prCmd
  if platform == "gitlab" then
    prCmd = "glab mr list --state opened" .. repoFlag .. " 2>/dev/null | grep -c '^!'"
  else
    prCmd = "gh pr list" .. repoFlag .. " --json number 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d))'"
  end

  noctalia.runAsync(prCmd, function(res)
    if res.exitCode == 0 then
      prCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
      updateState()
    end
  end)

  -- Fetch issues
  local issueCmd
  if platform == "gitlab" then
    issueCmd = "glab issue list --state opened" .. repoFlag .. " 2>/dev/null | grep -c '^#'"
  else
    issueCmd = "gh issue list" .. repoFlag .. " --json number 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d))'"
  end

  noctalia.runAsync(issueCmd, function(res)
    if res.exitCode == 0 then
      issueCount = tonumber((res.stdout or res.body or "0"):gsub("\n", "")) or 0
      updateState()
    end
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  end
end)

refresh()

local interval = (tonumber(noctalia.getConfig("refreshInterval")) or 60) * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
