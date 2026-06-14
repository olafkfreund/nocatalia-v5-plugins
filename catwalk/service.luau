-- Catwalk — background service.
-- Calculates CPU usage from /proc/stat and updates the state.

noctalia.setUpdateInterval(2000)

local lastTotal = 0
local lastIdle = 0

local function checkCpu()
  noctalia.runAsync("cat /proc/stat", function(res)
    if res.exitCode ~= 0 then return end
    
    local line = res.stdout:match("^(cpu%s+.-)\n")
    if not line then return end
    
    local parts = {}
    for part in line:gmatch("%S+") do
      table.insert(parts, tonumber(part) or 0)
    end
    
    local user = parts[2]
    local nice = parts[3]
    local system = parts[4]
    local idle = parts[5]
    local iowait = parts[6]
    local irq = parts[7]
    local softirq = parts[8]
    local steal = parts[9]
    
    local total = user + nice + system + idle + iowait + irq + softirq + steal
    local idleTime = idle + iowait
    
    if lastTotal > 0 then
      local totalDelta = total - lastTotal
      local idleDelta = idleTime - lastIdle
      if totalDelta > 0 then
        local usage = 100 * (1 - idleDelta / totalDelta)
        noctalia.state.set("cpuUsage", usage)
        
        local thresh = noctalia.getConfig("minimumThreshold") or 10
        noctalia.state.set("isRunning", usage >= thresh)
      end
    end
    
    lastTotal = total
    lastIdle = idleTime
  end)
end

function update()
  checkCpu()
end
