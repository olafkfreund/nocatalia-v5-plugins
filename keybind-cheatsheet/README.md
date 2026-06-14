# Keybind Cheatsheet

Universal keyboard shortcuts cheatsheet plugin for Noctalia that **automatically detects** your compositor (Hyprland, Niri, or MangoWC) and displays your keybindings via the launcher search provider.

![Preview](preview.png)

---

## Features

- **Automatic Compositor Detection:** Detects if you are running Niri, Hyprland, or MangoWC.
- **Launcher Search Provider:** Type `/keys <filter>` in the launcher to browse and search your active shortcuts. Press Enter on any result to copy the shortcut combination to your clipboard.
- **Bar Widget Integration:** Shows a keyboard icon on the bar, hovering displays active compositor and the number of loaded shortcuts. Clicking toggles the launcher search immediately.
- **Configurable Paths:** Custom configuration paths for each compositor.

---

## Configuration

Configure settings globally in Noctalia's plugin manager under *Settings → Plugins*:

- `hyprland_config_path`: Path to your Hyprland configuration file (default `~/.config/hypr/hyprland.conf`).
- `niri_config_path`: Path to your Niri configuration file (default `~/.config/niri/config.kdl`).
- `mango_config_path`: Path to your MangoWC configuration file (default `~/.config/mango/config.conf`).

---

## File Layout

```
keybind-cheatsheet/
├── plugin.toml         # Plugin manifest and settings schema
├── service.luau        # Background service that parses keybindings
├── widget.luau         # Bar widget representation
├── launcher.luau       # Launcher provider (/keys query handler)
├── translations/
│   └── en.json         # Dotted-key translations
├── preview.png
└── README.md
```

---

## License

MIT
