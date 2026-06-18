-- widget.luau
-- Bar widget for not-just-text plugin.
-- Reads displayText from service state and renders it in the bar.

barWidget.setGlyph("writing")
barWidget.setGlyphColor("on_surface")
barWidget.setText("…")
barWidget.setTooltip("…")

-- Watch for text updates from the service
noctalia.state.watch("displayText", function(value)
    local text = value or ""
    barWidget.setText(text)
    barWidget.setTooltip(text)
end)

-- Left-click triggers a refresh via state
function onClick()
    noctalia.state.set("command", "refresh")
end

-- update() is called periodically; disable auto-polling
function update()
    noctalia.setUpdateInterval(0)
end
