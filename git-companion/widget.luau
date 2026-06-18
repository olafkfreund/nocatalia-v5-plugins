-- Git Companion — bar widget.

local prCount = 0
local issueCount = 0
local available = false
local errorMsg = ""

local function render()
  barWidget.setGlyph("git-branch")

  if not available then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Git Companion: " .. (errorMsg ~= "" and errorMsg or "not available"))
    return
  end

  local total = prCount + issueCount
  if total > 0 then
    barWidget.setGlyphColor("primary")
    barWidget.setText(tostring(total))
    local tooltip = ""
    if prCount > 0 then
      tooltip = prCount .. " open PR(s)"
    end
    if issueCount > 0 then
      if tooltip ~= "" then tooltip = tooltip .. " | " end
      tooltip = tooltip .. issueCount .. " open issue(s)"
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Git Companion: No open PRs or issues")
  end
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("prCount", function(val)
  prCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("issueCount", function(val)
  issueCount = tonumber(val) or 0
  render()
end)

noctalia.state.watch("available", function(val)
  available = val == true
  render()
end)

noctalia.state.watch("errorMsg", function(val)
  errorMsg = val or ""
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
