# Claude Code — Noctalia Plugin

Run **Claude Code** (Anthropic's agentic CLI) inside your Noctalia shell with terminal launcher integration and a quick search provider.

![status: active](https://img.shields.io/badge/status-active-green)
![license: MIT](https://img.shields.io/badge/license-MIT-blue)
![noctalia](https://img.shields.io/badge/noctalia-%E2%89%A5%205.0.0-6c5ce7)

---

## Features

- **Terminal Integration:** Click the bar widget to open or resume a full interactive Claude Code session in your configured terminal.
- **Process Monitoring:** The bar widget dynamically monitors the active Claude Code process (changing color to green when running, grey when unavailable, and standard when idle).
- **Launcher Provider:** Run one-shot queries directly from the launcher by typing `/claude <prompt>`. Preview the multi-line result and press Enter to copy the entire response to your clipboard.
- **Noctalia Context Injection:** Optionally inject a system prompt that gives Claude awareness of the Noctalia IPC surface so it can control your desktop (dark mode, brightness, media, etc.) directly.
- **Bypass Prompting:** Option to run with `--dangerously-skip-permissions` for quick, sandboxed workflows.

---

## Requirements

- **Noctalia Shell ≥ 5.0.0**
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
- Authenticate it once: `claude` (Anthropic account, Bedrock, or Vertex)

---

## File Layout

```
claude-code-panel/
├── plugin.toml         # Plugin manifest and settings schema
├── service.luau        # Background process monitoring service
├── widget.luau         # Bar widget representation and terminal execution
├── launcher.luau       # Launcher provider (/claude search handler)
├── translations/
│   └── en.json         # Dotted-key translations
├── preview.png
└── README.md
```

---

## Settings Reference

These settings are managed declaratively in the shell's plugin manager under *Settings → Plugins*:

| Key | Type | Default | Description |
|---|---|---|---|
| `binary` | string | `"claude"` | Name or full path of the Claude Code CLI binary. |
| `working_dir` | string | `""` | Directory where Claude Code will start. |
| `model` | string | `""` | Overrides the default model (e.g. `claude-3-7-sonnet-latest`). |
| `allowed_tools` | string | `""` | Comma-separated list of allowed tools. |
| `disallowed_tools` | string | `""` | Comma-separated list of disallowed tools. |
| `dangerously_skip_permissions` | bool | `false` | Bypass all tool prompts (dangerous, use in sandboxes). |
| `inject_noctalia_context` | bool | `true` | Tells Claude about Noctalia's IPC targets. |

---

## License

MIT
