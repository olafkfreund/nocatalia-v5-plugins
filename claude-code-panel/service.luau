-- Headless [[service]] entry: runs in the background.
-- Periodically checks if the Claude binary exists and if Claude is currently running.

noctalia.setUpdateInterval(1000) -- Tick once a second

local isAvailable = false
local lastBinary = nil

local function checkAvailability(binary)
  return noctalia.commandExists(binary)
end

local function getBinaryName(path)
  local name = path:match("([^/]+)$")
  return name or path
end

function update()
  local binaryPath = noctalia.getConfig("binary") or "claude"
  
  -- Handle binary setting changes at runtime
  if binaryPath ~= lastBinary then
    lastBinary = binaryPath
    isAvailable = checkAvailability(binaryPath)
    noctalia.state.set("available", isAvailable)
  end

  local binaryName = getBinaryName(binaryPath)

  -- Check if the Claude process is currently running
  noctalia.processMatches(function(matched)
    noctalia.state.set("running", matched)
  end, binaryName)
end
