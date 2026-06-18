-- kubectl-ctx — background service.
-- Shows and switches Kubernetes contexts via kubectl.

local currentContext = ""
local contexts = {}
local available = false
local errorMsg = ""

local function kubeEnv()
  local cfg = noctalia.getConfig("kubeconfigPath") or ""
  if cfg ~= "" then
    return "KUBECONFIG=" .. cfg .. " "
  end
  return ""
end

local function updateState()
  noctalia.state.set("currentContext", currentContext)
  noctalia.state.set("contextCount", #contexts)
  noctalia.state.set("available", available)
  noctalia.state.set("errorMsg", errorMsg)
  local ctxList = table.concat(contexts, ";")
  noctalia.state.set("contexts", ctxList)
end

local function refresh()
  local env = kubeEnv()
  noctalia.runAsync(env .. "kubectl config current-context 2>/dev/null", function(res)
    if res.exitCode ~= 0 then
      available = false
      errorMsg = "kubectl unavailable"
      updateState()
      return
    end
    available = true
    errorMsg = ""
    currentContext = (res.stdout or res.body or ""):gsub("\n", "")
    updateState()
  end)

  noctalia.runAsync(env .. "kubectl config get-contexts -o name 2>/dev/null", function(res)
    if res.exitCode == 0 then
      local ctxs = {}
      for ctx in (res.stdout or res.body or ""):gmatch("[^\n]+") do
        ctx = ctx:gsub("^%s+", ""):gsub("%s+$", "")
        if ctx ~= "" then ctxs[#ctxs + 1] = ctx end
      end
      contexts = ctxs
      updateState()
    end
  end)
end

local function switchContext(ctx)
  local env = kubeEnv()
  noctalia.runAsync(env .. 'kubectl config use-context "' .. ctx .. '" 2>/dev/null', function(res)
    refresh()
  end)
end

noctalia.state.watch("command", function(cmd)
  if cmd == "refresh" then
    refresh()
  elseif cmd and cmd:sub(1, 7) == "switch:" then
    switchContext(cmd:sub(8))
  end
end)

refresh()

local interval = (tonumber(noctalia.getConfig("pollInterval")) or 60) * 1000
noctalia.setUpdateInterval(interval)

function onUpdate()
  refresh()
end
