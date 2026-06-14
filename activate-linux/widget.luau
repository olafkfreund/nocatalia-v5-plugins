-- Activate Linux Watermark — desktop widget.
-- Displays a semi-transparent activation warning overlay.

local osName = "Linux"

local function render()
  local customize = desktopWidget.getConfig("customizeText") == true
  
  local firstLine
  local secondLine

  if customize then
    firstLine = desktopWidget.getConfig("firstLine") or "Activate Linux"
    secondLine = desktopWidget.getConfig("secondLine") or "Go to Settings to activate Linux."
  else
    local actPattern = noctalia.tr("panel.activate") or "Activate {osName}"
    local setPattern = noctalia.tr("panel.goto_settings") or "Go to Settings to activate {osName}."
    firstLine = string.gsub(actPattern, "{osName}", osName)
    secondLine = string.gsub(setPattern, "{osName}", osName)
  end

  desktopWidget.render(ui.column({ gap = 4, align = "left" }, {
    ui.label({
      text = firstLine,
      fontSize = 22,
      color = "on_surface_variant",
    }),
    ui.label({
      text = secondLine,
      fontSize = 14,
      color = "on_surface_variant",
    })
  }))
end

function update()
  noctalia.setUpdateInterval(0) -- Static display, updates triggered by settings or load
  
  noctalia.runAsync("awk -F= '/PRETTY_NAME/{print $2}' /etc/os-release | tr -d '\"'", function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      osName = string.gsub(res.stdout, "\n", "")
    end
    render()
  end)
end
