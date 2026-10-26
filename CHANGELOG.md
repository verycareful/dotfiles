# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow a four-part
`Major.Major.Minor.Patch` scheme: a fix bumps Patch, a feature bumps Minor and resets Patch.

## [Unreleased]

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
