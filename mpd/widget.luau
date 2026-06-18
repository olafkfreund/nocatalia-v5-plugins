-- MPD — bar widget.

local title = ""
local artist = ""
local status = "stopped"
local mpcAvailable = false

local function render()
  if not mpcAvailable then
    barWidget.setGlyph("music")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("MPD: mpc not available")
    return
  end

  if status == "playing" then
    barWidget.setGlyph("player-play")
    barWidget.setGlyphColor("primary")
    local display = title ~= "" and title or "Playing"
    barWidget.setText(display)
    local tooltip = "Playing"
    if artist ~= "" then
      tooltip = display .. " by " .. artist
    end
    barWidget.setTooltip(tooltip)
  elseif status == "paused" then
    barWidget.setGlyph("player-pause")
    barWidget.setGlyphColor("on_surface_variant")
    local display = title ~= "" and title or "Paused"
    barWidget.setText(display)
    barWidget.setTooltip("Paused: " .. display)
  else
    barWidget.setGlyph("music")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("MPD: Stopped")
  end
end

function onClick()
  local action = barWidget.getConfig("leftButton") or "next"
  noctalia.state.set("command", action)
end

function onRightClick()
  local action = barWidget.getConfig("rightButton") or "toggle"
  noctalia.state.set("command", action)
end

noctalia.state.watch("status", function(val)
  status = val or "stopped"
  render()
end)

noctalia.state.watch("title", function(val)
  title = val or ""
  render()
end)

noctalia.state.watch("artist", function(val)
  artist = val or ""
  render()
end)

noctalia.state.watch("mpcAvailable", function(val)
  mpcAvailable = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
