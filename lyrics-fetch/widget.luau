-- Lyrics Fetch — bar widget.

local currentTitle = ""
local currentArtist = ""
local isPlaying = false

local function render()
  barWidget.setGlyph("file-text")
  if not isPlaying then
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("Lyrics: Not playing")
    return
  end

  barWidget.setGlyphColor("primary")
  local display = currentTitle ~= "" and ("♪ " .. currentTitle) or "♪"
  if #display > 40 then display = display:sub(1, 37) .. "..." end
  barWidget.setText(display)
  barWidget.setTooltip("Lyrics: " .. currentTitle .. " — " .. currentArtist)
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

noctalia.state.watch("isPlaying", function(val)
  isPlaying = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(0)
  render()
end
