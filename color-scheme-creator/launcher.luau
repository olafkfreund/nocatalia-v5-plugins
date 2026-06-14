-- Color Scheme Creator — launcher provider.
-- Quick apply preset themes or custom themes.

local PRESETS = {
  {
    id = "catppuccin",
    title = "Catppuccin Mocha",
    subtitle = "Soothe pastel theme for the high-spirited!",
    colors = {
      mPrimary = "#cba6f7", mOnPrimary = "#11111b",
      mSecondary = "#b4befe", mOnSecondary = "#11111b",
      mTertiary = "#f5c2e7", mOnTertiary = "#11111b",
      mError = "#f38ba8", mOnError = "#11111b",
      mSurface = "#1e1e2e", mOnSurface = "#cdd6f4",
      mSurfaceVariant = "#313244", mOnSurfaceVariant = "#a6adc8",
      mOutline = "#585b70", mShadow = "#11111b",
      mHover = "#313244", mOnHover = "#cdd6f4"
    }
  },
  {
    id = "gruvbox",
    title = "Gruvbox Dark",
    subtitle = "Retro groove color scheme for vim",
    colors = {
      mPrimary = "#d65d0e", mOnPrimary = "#fbf1c7",
      mSecondary = "#b8bb26", mOnSecondary = "#282828",
      mTertiary = "#8ec07c", mOnTertiary = "#282828",
      mError = "#fb4934", mOnError = "#282828",
      mSurface = "#282828", mOnSurface = "#ebdbb2",
      mSurfaceVariant = "#3c3836", mOnSurfaceVariant = "#a89984",
      mOutline = "#504945", mShadow = "#1d2021",
      mHover = "#3c3836", mOnHover = "#ebdbb2"
    }
  },
  {
    id = "nord",
    title = "Nord",
    subtitle = "An arctic, north-bluish color palette",
    colors = {
      mPrimary = "#88c0d0", mOnPrimary = "#2e3440",
      mSecondary = "#81a1c1", mOnSecondary = "#2e3440",
      mTertiary = "#b48ead", mOnTertiary = "#2e3440",
      mError = "#bf616a", mOnError = "#2e3440",
      mSurface = "#2e3440", mOnSurface = "#d8dee9",
      mSurfaceVariant = "#3b4252", mOnSurfaceVariant = "#e5e9f0",
      mOutline = "#4c566a", mShadow = "#242933",
      mHover = "#3b4252", mOnHover = "#d8dee9"
    }
  },
  {
    id = "dracula",
    title = "Dracula",
    subtitle = "A dark theme for many editors",
    colors = {
      mPrimary = "#bd93f9", mOnPrimary = "#282a36",
      mSecondary = "#ff79c6", mOnSecondary = "#282a36",
      mTertiary = "#8be9fd", mOnTertiary = "#282a36",
      mError = "#ff5555", mOnError = "#282a36",
      mSurface = "#282a36", mOnSurface = "#f8f8f2",
      mSurfaceVariant = "#44475a", mOnSurfaceVariant = "#6272a4",
      mOutline = "#6272a4", mShadow = "#191a21",
      mHover = "#44475a", mOnHover = "#f8f8f2"
    }
  }
}

function onQuery(query)
  local filter = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local results = {}

  for _, p in PRESETS do
    if filter == "" or p.title:lower():find(filter, 1, true) then
      table.insert(results, {
        id = p.id,
        title = p.title,
        subtitle = p.subtitle,
        glyph = "palette"
      })
    end
  end

  if #results == 0 then
    table.insert(results, {
      id = "empty",
      title = "No themes found",
      subtitle = "No preset matched your query",
      glyph = "alert-circle"
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id)
  local selectedPreset = nil
  for _, p in PRESETS do
    if p.id == id then
      selectedPreset = p
      break
    end
  end

  if not selectedPreset then return end

  local home = os.getenv("HOME") or "/tmp"
  local themeName = selectedPreset.id
  local dirPath = `{home}/.config/noctalia/colorschemes/{themeName}`
  local filePath = `{dirPath}/{themeName}.json`

  local schemeJson = noctalia.json.encode({
    dark = selectedPreset.colors,
    light = selectedPreset.colors
  })

  noctalia.runAsync(`mkdir -p '{dirPath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{schemeJson:gsub("'", "'\\''")}' '{filePath}'`, function(writeRes)
        if writeRes.exitCode == 0 then
          noctalia.runAsync(`qs -c noctalia-shell ipc call colorScheme predefined set '{themeName}'`, function(ipcRes)
            noctalia.notify("Theme Manager", `Theme '{selectedPreset.title}' applied successfully!`)
          end)
        else
          noctalia.notify("Theme Manager", "Failed to save theme file.")
        end
      end)
    else
      noctalia.notify("Theme Manager", "Failed to create theme directory.")
    end
  end)
end
