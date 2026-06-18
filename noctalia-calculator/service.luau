-- Noctalia Calculator — background service.
-- Evaluates math expressions using Python (bc or python3).

local currentValue = "0"
local expression = ""
local hasError = false

local function updateState()
  noctalia.state.set("currentValue", currentValue)
  noctalia.state.set("expression", expression)
  noctalia.state.set("hasError", hasError)
end

local function evaluate(expr)
  if expr == "" then return end
  expression = expr
  local precision = tonumber(noctalia.getConfig("precision")) or 8
  -- Use python3 to evaluate - more powerful than bc
  local cmd = "python3 -c \"import math; result = eval('" .. expr:gsub("'", "\\'") .. "'); print(round(result, " .. tostring(precision) .. ") if isinstance(result, float) else result)\" 2>/dev/null"
  noctalia.runAsync(cmd, function(res)
    if res.exitCode == 0 then
      local val = (res.stdout or res.body or ""):gsub("\n", "")
      currentValue = val ~= "" and val or "0"
      hasError = false
    else
      currentValue = "Error"
      hasError = true
    end
    updateState()
  end)
end

noctalia.state.watch("expression", function(expr)
  if expr and expr ~= "" then
    evaluate(expr)
  end
end)

noctalia.state.watch("command", function(cmd)
  if cmd == "clear" then
    currentValue = "0"
    expression = ""
    hasError = false
    updateState()
  end
end)

updateState()

noctalia.setUpdateInterval(0)
