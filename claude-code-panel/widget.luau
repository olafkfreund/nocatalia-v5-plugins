-- Claude Code — bar widget.
-- Shows current process status and launches Claude Code in the terminal.

local running = false
local available = false

local function buildCommand()
  local binary = barWidget.getConfig("binary") or "claude"
  local workingDir = barWidget.getConfig("working_dir") or ""
  local model = barWidget.getConfig("model") or ""
  local allowedTools = barWidget.getConfig("allowed_tools") or ""
  local disallowedTools = barWidget.getConfig("disallowed_tools") or ""
  local dangerous = barWidget.getConfig("dangerously_skip_permissions") == true
  local injectContext = barWidget.getConfig("inject_noctalia_context") ~= false

  local cmdParts = { binary }

  if model ~= "" then
    table.insert(cmdParts, `--model {model}`)
  end

  if allowedTools ~= "" then
    table.insert(cmdParts, `--allowedTools {allowedTools}`)
  end

  if disallowedTools ~= "" then
    table.insert(cmdParts, `--disallowedTools {disallowedTools}`)
  end

  if dangerous then
    table.insert(cmdParts, "--dangerously-skip-permissions")
  end

  if injectContext then
    local promptText = [[You are Claude running under the **claude-code-panel** plugin in **Noctalia Shell** (a C++ based Wayland desktop shell).

## Desktop control — Noctalia IPC
Invoke IPC from Bash:
noctalia msg <command> [args...]

Discovery (use first when unsure):
- noctalia msg status — JSON snapshot of current shell state
- noctalia msg --help — list all available commands and arguments

Common commands:
- Appearance: theme-mode-set <dark|light|auto>, theme-mode-toggle, wallpaper-set <path>, wallpaper-random
- Shell UI: panel-toggle <launcher|control-center>, settings-toggle, dock-toggle
- Session & Power: session <lock|suspend|reboot|shutdown>, caffeine-toggle, power-set <profile>
- Hardware: volume-set <0-100>, volume-mute, brightness-up [step], brightness-down [step], wifi-toggle
- Media: media <next|previous|toggle|stop>

## Conventions
- IPC first for desktop actions ("dark mode", "lock screen", "set wallpaper") — immediate, reversible, no config mutation.
- Code tasks: behave as standard Claude Code. The Noctalia context is additive.]]

    local escapedPrompt = promptText:gsub("'", "'\\''")
    table.insert(cmdParts, `--append-system-prompt '{escapedPrompt}'`)
  end

  local cdCmd = ""
  if workingDir ~= "" then
    cdCmd = `cd {workingDir} && `
  end

  return cdCmd .. table.concat(cmdParts, " ")
end

local function render()
  if not available then
    barWidget.setGlyph("terminal")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText(noctalia.tr("widget.label.unavailable"))
    barWidget.setTooltip(noctalia.tr("widget.tooltip.unavailable"))
    return
  end

  if running then
    barWidget.setGlyph("terminal")
    barWidget.setGlyphColor("success")
    barWidget.setText(noctalia.tr("widget.label.running"))
    barWidget.setTooltip(noctalia.tr("widget.tooltip.running"))
  else
    barWidget.setGlyph("terminal")
    barWidget.setGlyphColor("on_surface")
    barWidget.setText(noctalia.tr("widget.label.idle"))
    barWidget.setTooltip(noctalia.tr("widget.tooltip.idle"))
  end
end

function onClick()
  if not available then
    noctalia.notify(
      noctalia.tr("widget.error.title"),
      noctalia.tr("widget.error.not_found")
    )
    return
  end
  local cmd = buildCommand()
  noctalia.runInTerminal(cmd)
end

-- Sync the initial state and watch changes
available = noctalia.state.get("available") == true
running = noctalia.state.get("running") == true
render()

noctalia.state.watch("available", function(val)
  available = val == true
  render()
end)

noctalia.state.watch("running", function(val)
  running = val == true
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end
