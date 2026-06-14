-- Claude Code — launcher provider.
-- Accepts queries via `/claude <prompt>` and runs them one-shot in the background.

local lastResponse = ""

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buildQueryCommand(prompt)
  local binary = noctalia.getConfig("binary") or "claude"
  local workingDir = noctalia.getConfig("working_dir") or ""
  local model = noctalia.getConfig("model") or ""
  local allowedTools = noctalia.getConfig("allowed_tools") or ""
  local disallowedTools = noctalia.getConfig("disallowed_tools") or ""
  local dangerous = noctalia.getConfig("dangerously_skip_permissions") == true
  local injectContext = noctalia.getConfig("inject_noctalia_context") ~= false

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

  local escapedPrompt = prompt:gsub("'", "'\\''")
  table.insert(cmdParts, `-p '{escapedPrompt}'`)

  local cdCmd = ""
  if workingDir ~= "" then
    cdCmd = `cd {workingDir} && `
  end

  return cdCmd .. table.concat(cmdParts, " ")
end

local function hintRow(title, subtitle, glyph)
  return { id = "hint", title = title, subtitle = subtitle, glyph = glyph }
end

local function resultRows(stdout)
  local rows = {}
  table.insert(rows, {
    id = "copy_all",
    title = noctalia.tr("launcher.results.copy"),
    subtitle = "Copy all output to clipboard",
    glyph = "copy",
  })

  local lineCount = 0
  for line in stdout:gmatch("[^\r\n]+") do
    if line:gsub("%s+", "") ~= "" then
      lineCount += 1
      if lineCount > 6 then
        table.insert(rows, {
          id = "more_lines",
          title = "...",
          subtitle = "More output available. Press Copy above.",
          glyph = "more-horizontal",
        })
        break
      end
      table.insert(rows, {
        id = `line_{lineCount}`,
        title = line,
        subtitle = `Line {lineCount}`,
        glyph = "align-left",
      })
    end
  end

  if lineCount == 0 then
    table.insert(rows, {
      id = "empty",
      title = noctalia.tr("launcher.results.empty"),
      subtitle = "",
      glyph = "alert-circle",
    })
  end

  return rows
end

function onQuery(query)
  local prompt = trim(query)
  if prompt == "" then
    launcher.setResults(query, {
      hintRow(
        noctalia.tr("launcher.hint.title"),
        noctalia.tr("launcher.hint.desc"),
        "terminal"
      )
    })
    return
  end

  -- Display thinking state
  launcher.setResults(query, {
    hintRow(
      noctalia.tr("launcher.query.thinking"),
      prompt,
      "loader"
    )
  })

  local cmd = buildQueryCommand(prompt)
  noctalia.runAsync(cmd, function(result)
    if result.exitCode ~= 0 then
      local errText = if result.stderr ~= "" then result.stderr else `Exit code {result.exitCode}`
      lastResponse = errText
      launcher.setResults(query, {
        {
          id = "copy_all",
          title = noctalia.tr("launcher.error.title"),
          subtitle = errText,
          glyph = "alert-triangle",
        }
      })
      return
    end

    lastResponse = result.stdout
    launcher.setResults(query, resultRows(result.stdout))
  end)
end

function onActivate(id)
  if id == "copy_all" and lastResponse ~= "" then
    noctalia.copyToClipboard(lastResponse, "text/plain")
    noctalia.notify(
      noctalia.tr("widget.error.title"),
      noctalia.tr("launcher.results.copied")
    )
  end
end
