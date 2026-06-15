-- Hello World — background service.
-- Periodically logs hello messages and handles custom state / commands.

noctalia.setUpdateInterval(10000) -- Tick every 10 seconds

local count = 0

function update()
  count += 1
  local msg = noctalia.getConfig("message") or "Hello World"
  noctalia.log(`HelloWorld Service Tick #{count}: {msg}`)
end
