-- MPRIS Lyric — bar widget.

local currentTitle = ""
local currentArtist = ""
local currentLyric = ""
local isPlaying = false

local function render()
  barWidget.setGlyph("music")

  local hideInactive = barWidget.getConfig("hideWhenInactive") == true

  if not isPlaying then
    if hideInactive then
      barWidget.setVisible(false)
      return
    end
    barWidget.setVisible(true)
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("MPRIS Lyric: Not playing")
    return
  end

  barWidget.setVisible(true)
  barWidget.setGlyphColor("primary")

  local display = currentLyric ~= "" and currentLyric or (currentTitle ~= "" and ("♪ " .. currentTitle) or "♪")
  -- Truncate long lyrics for bar display
  if #display > 50 then
    display = display:sub(1, 47) .. "..."
  end
  barWidget.setText(display)
  barWidget.setTooltip(currentTitle ~= "" and (currentTitle .. " — " .. currentArtist) or "Playing")
end

function onClick()
  noctalia.state.set("command", "refresh")
end

noctalia.state.watch("currentTitle", function(val)
  currentTitle = val or ""
  render()
end)

noctalia.state.watch("currentArtist", function(val)
  currentArtist = val or ""
  render()
end)

noctalia.state.watch("currentLyric", function(val)
  currentLyric = val or ""
  render()
end)

noctalia.state.watch("isPlaying", function(val)
  isPlaying = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
