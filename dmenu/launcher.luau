-- Dmenu Provider — launcher provider.

local active = false
local items = {}
local prompt = "Search:"

function onQuery(query)
	if not active then
		launcher.setResults(query, {})
		return
	end

	local search = query:gsub("^/dmenu%s*", ""):lower()
	local results = {}

	for _, item in ipairs(items) do
		local name = item.name or ""
		local desc = item.description or ""
		if name:lower():find(search, 1, true) or desc:lower():find(search, 1, true) then
			table.insert(results, {
				id = `{item.index}:{item.value}`,
				title = name,
				subtitle = desc ~= "" and desc or item.value,
				glyph = item.icon ~= "" and item.icon or "search",
			})
		end
	end

	launcher.setResults(query, results)
end

function onActivate(id)
	local idxStr, val = id:match("^([^:]+):(.*)$")
	local index = tonumber(idxStr)
	if index and val then
		noctalia.state.set("command", { action = "select", value = val, index = index })
	end
end

noctalia.state.watch("dmenu_active", function(val)
	active = val == true
end)

noctalia.state.watch("dmenu_items", function(val)
	items = if type(val) == "table" then val else {}
end)

noctalia.state.watch("dmenu_prompt", function(val)
	if type(val) == "string" then
		prompt = val
	end
end)
