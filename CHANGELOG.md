# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow a four-part
`Major.Major.Minor.Patch` scheme: a fix bumps Patch, a feature bumps Minor and resets Patch.

## [Unreleased]

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
