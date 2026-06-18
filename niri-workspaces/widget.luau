-- Niri Workspaces — bar widget.

local workspaceNames = ""
local activeWorkspace = 0
local workspaceCount = 0

local function render()
  barWidget.setGlyph("layout-grid")

  if workspaceCount == 0 then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Niri Workspaces: Not running")
    return
  end

  barWidget.setGlyphColor("primary")
  barWidget.setText(tostring(activeWorkspace))
  barWidget.setTooltip("Niri: Workspace " .. activeWorkspace .. " of " .. workspaceCount .. " | Click to switch")
end

function onClick()
  -- Focus next workspace
  local next = activeWorkspace + 1
  if next > workspaceCount then next = 1 end
  noctalia.state.set("command", "focus:" .. tostring(next))
end

function onScrollUp()
  local prev = activeWorkspace - 1
  if prev < 1 then prev = workspaceCount end
  noctalia.state.set("command", "focus:" .. tostring(prev))
end

function onScrollDown()
  local next = activeWorkspace + 1
  if next > workspaceCount then next = 1 end
  noctalia.state.set("command", "focus:" .. tostring(next))
end

noctalia.state.watch("workspaceNames", function(val)
  workspaceNames = val or ""
  render()
end)

noctalia.state.watch("activeWorkspace", function(val)
  activeWorkspace = tonumber(val) or 0
  render()
end)

noctalia.state.watch("workspaceCount", function(val)
  workspaceCount = tonumber(val) or 0
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
