-- File Search — background service.
-- Handles IPC commands to toggle/open file search.

noctalia.setUpdateInterval(0)

local function escapeShellArg(arg)
  return "'" .. string.gsub(arg, "'", "'\\''") .. "'"
end

noctalia.state.watch("command", function(cmd)
  if cmd == "toggle" then
    noctalia.runAsync("noctalia msg panel-toggle launcher \">file \"")
  elseif type(cmd) == "table" then
    local action = cmd.action or cmd[1]
    if action == "toggle" then
      noctalia.runAsync("noctalia msg panel-toggle launcher \">file \"")
    elseif action == "search" then
      local query = cmd.query or cmd[2] or ""
      noctalia.runAsync(string.format("noctalia msg panel-toggle launcher %s", escapeShellArg(">file " .. query)))
    end
  elseif type(cmd) == "string" then
    if cmd == "toggle" then
      noctalia.runAsync("noctalia msg panel-toggle launcher \">file \"")
    elseif cmd:match("^search%s") then
      local query = cmd:match("^search%s+(.*)$") or ""
      noctalia.runAsync(string.format("noctalia msg panel-toggle launcher %s", escapeShellArg(">file " .. query)))
    end
  end
end)

function update()
end
