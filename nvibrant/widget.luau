-- NVibrant — bar widget.
-- Toggles NVIDIA digital vibrance.

local home = os.getenv("HOME") or "/tmp"
local stateDir = `{home}/.cache/noctalia/plugins/nvibrant`
local statePath = `{stateDir}/state.json`

local enabled = false
local stateLoaded = false

local function loadState(callback)
  noctalia.runAsync(`test -f '{statePath}'`, function(res)
    if res.exitCode == 0 then
      noctalia.runAsync(`cat '{statePath}'`, function(catRes)
        local success, parsed = pcall(noctalia.json.decode, catRes.stdout or catRes.body or "")
        if success and type(parsed) == "table" and type(parsed.enabled) == "boolean" then
          enabled = parsed.enabled
        end
        stateLoaded = true
        if callback then callback() end
      end)
    else
      stateLoaded = true
      if callback then callback() end
    end
  end)
end

local function saveState()
  if not stateLoaded then return end
  local payload = noctalia.json.encode({ enabled = enabled })
  noctalia.runAsync(`mkdir -p '{stateDir}'`, function()
    local escapedPayload = payload:gsub("'", "'\\''")
    noctalia.runAsync(`bash -c "printf '%s' '$1' > '$2'" -- '{escapedPayload}' '{statePath}'`)
  end)
end

local function render()
  local exists = noctalia.commandExists("nvibrant")
  
  barWidget.setGlyph("contrast")
  
  if enabled then
    barWidget.setGlyphColor("primary")
  else
    barWidget.setGlyphColor("on_surface_variant")
  end

  local status = if enabled then "Enabled" else "Disabled"
  local displayIndex = barWidget.getConfig("displayIndex") or 1
  local vibranceValue = barWidget.getConfig("vibranceValue") or 512
  
  local tooltip = "NVIDIA Digital Vibrance\n"
  if not exists then
    tooltip ..= "⚠️ 'nvibrant' command not found\nPlease install nvibrant from GitHub or your package manager."
  else
    tooltip ..= `Status: {status}\nDisplay Index: {displayIndex}\nVibrance Value: {vibranceValue}\n\nLeft-click: Toggle`
  end
  barWidget.setTooltip(tooltip)
end

function onClick()
  if not stateLoaded then return end

  local exists = noctalia.commandExists("nvibrant")
  if not exists then
    noctalia.notify("NVibrant", "nvibrant command not found. Please install it.")
    return
  end

  enabled = not enabled
  saveState()
  
  local displayIndex = barWidget.getConfig("displayIndex") or 1
  local vibranceValue = barWidget.getConfig("vibranceValue") or 512
  
  local zeros = ""
  for i = 1, displayIndex - 1 do
    zeros ..= "0 "
  end
  
  local val = if enabled then vibranceValue else 0
  local cmd = `bash -lc 'nvibrant {zeros}{val}'`
  
  noctalia.runAsync(cmd)
  render()
end

function update()
  noctalia.setUpdateInterval(0)
  if not stateLoaded then
    loadState(render)
  else
    render()
  end
end
