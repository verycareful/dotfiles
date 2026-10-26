# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow a four-part
`Major.Major.Minor.Patch` scheme: a fix bumps Patch, a feature bumps Minor and resets Patch.

## [Unreleased]

## [1.0.2.1] - 2026-10-26 12:13 (IST)

### Fixed
- Waybar has no divider lines between modules on the right; spacing alone separates them.

### Results
53 tests across 2 suites, all passed, 3 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.016s, CachyOS Linux).

## [1.0.2.0] - 2026-10-26 12:12 (IST)

### Added
- `theme check` validates every theme against every template: each colour role and `name`, `mode`, `wallpaper`
  and `cursor` present, colours as six hex digits, `name` matching the file name, the wallpaper in `wallpapers/`,
  `glass` between 0 and 1, and every `{{key}}` in a template either set by the theme or given a fallback.
  `test/lint.sh` and CI run it.
- Every theme declares `mode=dark` or `mode=light`. Templates name the values that follow from it
  (`{{gtk_theme}}`, `{{gtk_prefer_dark}}`, `{{icon_theme}}`, `{{color_scheme}}`), so the GTK settings switch
  between adw-gtk3 and adw-gtk3-dark and between Papirus and Papirus-Dark with the theme.
- `theme set` sets GNOME's `color-scheme` from the theme's mode, so libadwaita and GTK4 apps switch while running.

### Changed
- Rendering lives in one place, `themes/render.py`, used by `theme set`, `theme render` and `theme check`.
  The output for harbour, mono and dusk is byte-identical.
- `theme set` checks the theme before writing anything. A theme with a missing key leaves the current colour
  files alone.

### Tests
- `themes/test/test_render.py`: theme parsing, derived values (`_rgb`, `_ansi`, `glass_hex`, mode values),
  placeholder fallbacks, each validation failure, rendering every target, a bad theme writing nothing, and every
  real theme rendering every template with no placeholder left.

### Results
53 tests across 2 suites, all passed, 3 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.016s, CachyOS Linux).

## [1.0.1.4] - 2026-10-26 12:03 (IST)

### Fixed
- Folders open in Thunar, the file manager SUPER+E starts. `install.sh` sets Thunar as the folder default, and the
  `thunar` package ships a user D-Bus service that gives `org.freedesktop.FileManager1` ("show in folder" from
  Firefox, Vesktop, VS Code) to Thunar. With Dolphin also installed, either could answer it before.
- `install.sh` creates `~/.local/share/dbus-1/services` before stowing, so only the service file is linked and
  services that apps install there stay out of the repo.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.1.3] - 2026-10-26 12:01 (IST)

### Added
- `install.sh` sets the default apps: Firefox for web links, Dolphin for folders, micro for plain text, Markdown
  and JSON. A default whose app is not installed is skipped. Apps keep registering their own handlers, so
  `mimeapps.list` itself stays untracked.

### Fixed
- Markdown files open in micro. Obsidian registered itself for them but opens only files inside one of its
  vaults, so any other `.md` file reopened the last vault instead.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.1.2] - 2026-10-26 11:52 (IST)

### Changed
- App launchers move from SUPER+SHIFT to SUPER+ALT: Firefox (F), Claude (C), VS Code (V), Spotify (O),
  Discord (D) and Signal (G). SUPER+SHIFT is left for moving windows.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.1.1] - 2026-10-26 11:51 (IST)

### Fixed
- Alt-Tab lists windows in the scratchpads (SUPER+S, SUPER+D, SUPER+Z), tagged with the scratchpad's name.
  Picking one opens its scratchpad and focuses it. Windows hidden to the tray (SUPER+M) stay out of the list.

### Changed
- SUPER+SHIFT+S/D/Z move the focused window into scratchpad 1/2/3. SUPER+ALT+S/D/Z no longer do.
- SUPER+ALT+D opens Vesktop, freeing SUPER+SHIFT+D for scratchpad 2.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.1.0] - 2026-10-21 17:32 (IST)

### Added
- Vesktop theme: `theme set` renders `dotfiles.theme.css` into Vesktop's themes folder and enables it once in its
  settings, keeping every other setting. It maps the active theme onto Discord's colour tokens (backgrounds, text,
  icons, borders, buttons, inputs, code syntax), sets small corner radii, and uses Oxanium, Quantico and
  Share Tech Mono. A theme switch applies while Vesktop is running.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.0.1] - 2026-10-21 17:20 (IST)

### Changed
- SUPER+SHIFT+D opens Vesktop instead of the official Discord client. Vesktop can share the audio of a single
  application with a screen share; the official Linux client sends the whole system's audio.
- ClamAV on-access scanning skips `~/.config/vesktop`, as it does `~/.config/discord`.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).

## [1.0.0.0] - 2026-10-21 17:12 (IST)

First versioned release. It records the configuration as it stands on CachyOS with Hyprland.

### Added
- Desktop: Hyprland (Lua config with the `conf.d` fallback), Waybar, Quickshell notifications and widget panel,
  rofi launcher, emoji picker, calculator and actions menu, wlogout, SDDM login theme.
- Terminal and shell: kitty, fish, Starship, fastfetch.
- Theming: switchable `*.theme` files rendered by `theme` into the desktop, GTK, Qt, btop, VS Code and Firefox;
  bundled Oxanium, Quantico and Share Tech Mono fonts.
- Helpers in `~/.local/bin`: clipboard history with thumbnails, screen recording, night light schedule, `doctor`.
- System: systemd-networkd and iwd networking, ClamAV on-access scanning, the permissions window, snapper
  snapshots, restic backup, ufw firewall, pacman hooks, OpenRGB presets, KDE Connect, LACT and RyzenAdj.
- `install.sh` and `restore.sh` for deploying with GNU Stow and rolling back.
- CI running ShellCheck, a Lua syntax check, the permissions tests and a secrets scan.
- `VERSION` file and this changelog.

### Tests
- `perms/`: 32 unit tests for the permissions rules.

### Results
32 tests across 1 suite, all passed, Lua syntax and secrets checks clean (0.004s, CachyOS Linux).
