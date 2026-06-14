# Show Keys

A desktop widget plugin for Noctalia Shell that displays keyboard input in real-time via `evtest`.

![Preview](preview.png)

---

## Features

- **Real-Time Capture:** Reads raw keyboard input events directly from your device using `evtest` in a background service.
- **Desktop Widget Representation:** Rendered as a draggable desktop widget. Move and position it anywhere on your desktop natively.
- **Smart Auto-Hide:** The key overlay automatically fades out gracefully after a custom amount of idle time.

---

## Prerequisites

This plugin relies on `evtest` to read hardware input directly. That means it needs access to `/dev/input/event*`, which comes with an explicit security tradeoff.

### Security Notice

Granting your user access to the `input` group weakens Wayland's input confidentiality model. Once your user can read raw input devices directly, any process running as that user may also be able to observe keyboard input outside the compositor's usual security boundaries.

Use this plugin only if you understand and accept that tradeoff. If you are not comfortable granting `input` access, do not enable this plugin until a compositor-native or otherwise safer input API exists.

1. **Install evtest** (for Arch Linux):
   ```bash
   sudo pacman -S evtest
   ```

2. **Grant input group permissions**:
   Add your user to the `input` group so the plugin can read inputs without requiring root access:
   ```bash
   sudo usermod -aG input $USER
   ```
   *(Warning: this is convenient, but it also grants raw input device access to processes running as your user.)*
   *(Note: You must log out and log back in, or reboot, for this group change to take effect.)*

3. **Find your keyboard device path**:
   Run the following command to list all input devices:
   ```bash
   sudo evtest
   ```
   Identify your primary keyboard from the list and note its event path (e.g., `/dev/input/event3`).

---

## Configuration & Usage

Configure settings globally in Noctalia's plugin manager under *Settings → Plugins*:

- `capture_enabled`: Enable or disable keyboard event capture.
- `evtest_device`: Your keyboard device event path (e.g., `/dev/input/event3`).
- `hide_delay_sec`: Seconds before the key overlay fades out.

---

## File Layout

```
show-keys/
├── plugin.toml         # Plugin manifest and settings schema
├── service.luau        # Background process monitoring and evtest stream parser
├── widget.luau         # Desktop widget representation
├── translations/
│   └── en.json         # Translation files
├── preview.png
└── README.md
```

---

## License

MIT
