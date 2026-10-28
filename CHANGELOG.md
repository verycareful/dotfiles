# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow a four-part
`Major.Major.Minor.Patch` scheme: a fix bumps Patch, a feature bumps Minor and resets Patch.

## [Unreleased]

## [1.0.8.0] - 2026-10-28 17:38 (IST)

### Added
- Releases from tag pushes: CI's `release` job runs on a pushed version tag once lint passes and creates its
  GitHub Release, titled from the annotated tag's message, with the version's CHANGELOG entry as notes.
- `.github/release.sh`: what the job runs. It refuses a tag that is not a four-part label, not annotated, whose
  `VERSION` disagrees with it, or whose CHANGELOG has no entry for it; a release that already exists is left as it
  is. `--dry-run` prints the title and notes without creating anything.

### Results
66 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.025s, CachyOS Linux).

## [1.0.7.0] - 2026-10-28 17:33 (IST)

### Added
- Calendar popup: clicking the date on the bar drops down a month calendar under it, today highlighted, with
  ‹ › to browse months (`qs ipc call calendar open|close|toggle`). Clicking the date again, Escape or a click
  outside closes it.
- Themes button in the widget panel's Lighting card: opens the theme window.

### Changed
- The calendar is no longer a card in the widget panel, and the date on the bar has no calendar tooltip; the
  popup replaces both.

### Results
66 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.026s, CachyOS Linux).

## [1.0.6.0] - 2026-10-28 17:24 (IST)

### Added
- Tray window on SUPER+SHIFT+M (`qs ipc call tray open|close|toggle`): a Quickshell window listing the windows
  hidden with SUPER+M, each with its icon, class and title and a close button on the right. A click or Enter
  brings a window to the current workspace and focuses it. The close button or Delete closes a hidden window
  where it is, without bringing it forward, and the list stays open. Arrow keys move, Escape closes.

### Removed
- `untray`: the rofi picker it showed is replaced by the tray window.

### Results
66 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.027s, CachyOS Linux).

## [1.0.5.0] - 2026-10-26 13:00 (IST)

### Added
- Song visualiser on the bar, shown only while a player is playing. SUPER+SHIFT+V, the Visualiser toggle in the
  widget panel or `qs ipc call panel viz` cycles its modes (`vizmode off|compact|wide|full` sets one):
  - compact: 12 bars beside the song title;
  - wide: the workspaces move next to the weather and 180 bars fill the centre of the bar;
  - full: thin bars across the whole bar, drawn by Quickshell beneath the modules.
  Bars are drawn in the theme's accent colour. cava runs only in the chosen mode while something plays.
- `viz` (`~/.local/bin`): feeds cava's output to the compact and wide Waybar modules.
- Audio capture in the permissions window and the bar's permissions pill: an app recording what is playing
  (such as cava) is shown under its own icon, watched like the camera, instead of counting as microphone use.

### Changed
- `packages.txt`: `cava` added; Waybar is `waybar-git` from the AUR, which the bar is set up against.

### Tests
- `perms`: sink-monitor capture is reported as audio capture, not the microphone; the bar line shows it.

### Results
66 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.026s, CachyOS Linux).

## [1.0.4.1] - 2026-10-26 12:32 (IST)

### Fixed
- Terminal text in light themes is solid instead of thin and grey. kitty's Linux text compositing is tuned for
  light text on dark; light themes set `text_composition_strategy 1.4 20`, dark themes keep kitty's default, and
  `theme set` reloads the setting in open terminals.
- VS Code in a light theme uses Default Light Modern underneath the theme's colours, so syntax highlighting is
  made for a light background. Dark themes set Default Dark Modern, VS Code's own default.

### Results
65 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.026s, CachyOS Linux).

## [1.0.4.0] - 2026-10-26 12:24 (IST)

### Added
- Theme window (SUPER+SHIFT+T, `theme window`, or Theme in the actions menu): a Quickshell window with a preview
  card per theme, each showing its wallpaper under a small mock bar and window drawn in its colours, dark and light
  halves side by side. A click or Enter applies the theme, arrow keys move between cards, and the window stays
  open while the shell reloads into the new colours.
- `theme json` prints every theme's name, mode, colours and wallpaper path, which the window reads.

### Changed
- SUPER+SHIFT+T opens the theme window instead of cycling to the next theme; `theme toggle` still cycles.

### Tests
- `theme json`: every theme listed with its colours, the wallpaper taken from the wallpaper folder when it is
  there and from the repo otherwise.

### Results
65 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.025s, CachyOS Linux).

## [1.0.3.0] - 2026-10-26 12:21 (IST)

### Added
- Light themes: `harbour-light`, `mono-light` and `dusk-light`, one beside each dark theme with the same accent
  and wallpaper.
- `theme light` and `theme dark` switch to the other half of the current pair.
- Derived colours that make one set of templates serve both modes: `on_accent` (text on an accent fill: the
  theme's own, else whichever of `base` and `text` contrasts more with the accent), ANSI black and white that stay
  dark and light on either background, and Qt bevel shades that keep their order.

### Changed
- Text on accent fills uses `on_accent` everywhere: GTK, kitty selection and cursor, VS Code buttons, Vesktop
  primary buttons, Waybar's urgent workspace and power hover, rofi's urgent row, the Quickshell notification count,
  reply button and calendar day, and the login button. Dusk sets it to black, so it looks as before.

### Fixed
- VS Code buttons drew light text on the accent (1.1:1 on mono's white, 1.9:1 on harbour's orange); they use
  `on_accent`.

### Tests
- Mode roles and `on_accent` (contrast choice, theme override, bad value), WCAG contrast at the extremes, every
  dark theme having a `-light` sibling, AA contrast for body text in every theme, and no Theme.qml property named
  like a QML signal handler.

### Results
62 tests across 2 suites, all passed, 6 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.025s, CachyOS Linux).

## [1.0.2.2] - 2026-10-26 12:15 (IST)

### Fixed
- A screenshot is copied to the clipboard as soon as it is taken, and satty opens hidden in the tray
  (`special:tray`) instead of over the current workspace. SUPER+SHIFT+M brings it up to annotate; Ctrl+S there
  saves to `~/Pictures/Screenshots`. The unannotated capture is kept only while satty is open.

### Results
53 tests across 2 suites, all passed, 3 themes checked against 23 templates, Lua syntax and secrets checks clean
(0.016s, CachyOS Linux).

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
