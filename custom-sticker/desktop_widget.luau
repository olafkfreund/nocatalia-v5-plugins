-- Custom Stickers — desktop widget.

local function render()
  local imagePath = noctalia.getConfig("image") or ""
  local opacity = noctalia.getConfig("opacity") or 1.0
  local mirror = noctalia.getConfig("mirror") == true
  local verticalMirror = noctalia.getConfig("verticalMirror") == true

  if imagePath == "" then
    desktopWidget.render(ui.column({ align = "center", gap = 8 }, {
      ui.label({
        text = "No Sticker Selected",
        fontSize = 14,
        fontWeight = "bold",
        color = "primary"
      }),
      ui.label({
        text = "Set an image in settings",
        fontSize = 11,
        color = "on_surface_variant"
      })
    }))
    return
  end

  desktopWidget.render(ui.box({
    width = 150,
    height = 150,
    opacity = opacity
  }, {
    ui.image({
      src = imagePath,
      mirror = mirror,
      mirrorVertically = verticalMirror,
      fillMode = "aspectFit"
    })
  }))
end

function update()
  render()
end
