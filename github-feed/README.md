# GitHub Feed Plugin for Noctalia

Displays GitHub unread notifications count in the bar and followed activity feed in the launcher search provider.

![Preview](preview.png)

---

## Features

- **Activity Feed in Launcher:** Type `/github <filter>` in the launcher to browse recent activity (stars, forks, pull requests, creations) from people you follow. Press Enter on any event to open the target URL directly in your default browser.
- **Bar Widget Integration:** Displays an unread notification count badge in your shell's bar. Hovering shows configuration info and status.
- **Background Polling:** A headless service runs in the background to fetch new notifications and feed items periodically.
- **Enterprise Support:** Configure a custom base URL to support GitHub Enterprise instances.

---

## Requirements

- **Noctalia Shell ≥ 5.0.0**
- A GitHub Personal Access Token with `read:user` and `notifications` scopes. Create one at: https://github.com/settings/tokens.

---

## Configuration

Configure settings globally in Noctalia's plugin manager under *Settings → Plugins*:

- `username`: Your GitHub username.
- `token`: Your GitHub Personal Access Token.
- `github_url`: Custom base URL (if using GitHub Enterprise Server).
- `refresh_interval`: Period in seconds between update checks (default 1800 / 30 mins).
- `max_events`: Maximum number of feed events to load.

---

## File Layout

```
github-feed/
├── plugin.toml         # Plugin manifest and settings schema
├── service.luau        # Background service that polls the GitHub APIs
├── widget.luau         # Bar widget representation
├── launcher.luau       # Launcher provider (/github query handler)
├── translations/
│   └── en.json         # Dotted-key translations
├── preview.png
└── README.md
```

---

## License

MIT
