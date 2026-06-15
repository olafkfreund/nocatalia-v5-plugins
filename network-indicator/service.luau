-- Network Indicator — background service.

noctalia.setUpdateInterval(1000)

local prevRx = 0
local prevTx = 0
local prevTime = 0

local function checkNetwork()
  noctalia.runAsync("cat /proc/net/dev 2>/dev/null", function(res)
    if res.exitCode ~= 0 then return end
    
    local rxTotal = 0
    local txTotal = 0
    
    for line in res.stdout:gmatch("[^\r\n]+") do
      local iface, rest = line:match("^%s*([%w%.%-]+):%s*(.*)$")
      if iface and iface ~= "lo" 
         and not iface:find("^docker") 
         and not iface:find("^virbr") 
         and not iface:find("^veth") 
         and not iface:find("^br%-") 
         and not iface:find("^tailscale") then
        local parts = {}
        for num in rest:gmatch("%d+") do
          table.insert(parts, tonumber(num) or 0)
        end
        if #parts >= 9 then
          rxTotal = rxTotal + parts[1]
          txTotal = txTotal + parts[9]
        end
      end
    end
    
    local currentTime = os.time()
    if prevTime > 0 and currentTime > prevTime then
      local dt = currentTime - prevTime
      local rxSpeed = (rxTotal - prevRx) / dt
      local txSpeed = (txTotal - prevTx) / dt
      
      if rxSpeed < 0 then rxSpeed = 0 end
      if txSpeed < 0 then txSpeed = 0 end
      
      noctalia.state.set("rxSpeed", rxSpeed)
      noctalia.state.set("txSpeed", txSpeed)
    else
      noctalia.state.set("rxSpeed", 0)
      noctalia.state.set("txSpeed", 0)
    end
    
    prevRx = rxTotal
    prevTx = txTotal
    prevTime = currentTime
  end)
end

function update()
  checkNetwork()
end
