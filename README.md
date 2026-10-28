# dotfiles
<!-- Platform -->
[![CachyOS](https://img.shields.io/badge/CachyOS-00B8A9?style=flat-square&logo=cachyos&logoColor=white)](https://cachyos.org/)
[![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=white)](https://wayland.freedesktop.org/)
<!-- Desktop -->
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=white)](https://hyprland.org/)
[![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org/)
[![Qt 6 QML](https://img.shields.io/badge/Qt%206%20QML-41CD52?style=flat-square&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qmlapplications.html)
<!-- Quickshell, Waybar, cava, rofi, wlogout, SDDM, kitty, fastfetch, Kvantum, systemd-networkd, iwd, OpenRGB, ClamAV, snapper, restic, ufw, gpu-screen-recorder and WirePlumber have no shields.io logos. Swap these plain badges for logo badges if logos become available. -->
[![Quickshell](https://img.shields.io/badge/Quickshell-3B4252?style=flat-square)](https://quickshell.org/)
[![Waybar](https://img.shields.io/badge/Waybar-3B4252?style=flat-square)](https://github.com/Alexays/Waybar)
[![cava](https://img.shields.io/badge/cava-3B4252?style=flat-square)](https://github.com/karlstav/cava)
[![rofi](https://img.shields.io/badge/rofi-3B4252?style=flat-square)](https://github.com/davatorium/rofi)
[![wlogout](https://img.shields.io/badge/wlogout-3B4252?style=flat-square)](https://github.com/ArtsyMacaw/wlogout)
[![SDDM](https://img.shields.io/badge/SDDM-3B4252?style=flat-square)](https://github.com/sddm/sddm)
[![Thunar](https://img.shields.io/badge/Thunar-2284F2?style=flat-square&logo=xfce&logoColor=white)](https://docs.xfce.org/xfce/thunar/start)
<!-- Terminal and shell -->
[![kitty](https://img.shields.io/badge/kitty-3B4252?style=flat-square)](https://sw.kovidgoyal.net/kitty/)
[![fish](https://img.shields.io/badge/fish-34C534?style=flat-square&logo=fishshell&logoColor=white)](https://fishshell.com/)
[![Starship](https://img.shields.io/badge/Starship-DD0B78?style=flat-square&logo=starship&logoColor=white)](https://starship.rs/)
[![fastfetch](https://img.shields.io/badge/fastfetch-3B4252?style=flat-square)](https://github.com/fastfetch-cli/fastfetch)
<!-- Theming -->
[![GTK](https://img.shields.io/badge/GTK-7FE719?style=flat-square&logo=gtk&logoColor=white)](https://www.gtk.org/)
[![Kvantum](https://img.shields.io/badge/Kvantum-3B4252?style=flat-square)](https://github.com/tsujan/Kvantum)
<!-- System -->
[![systemd-networkd](https://img.shields.io/badge/systemd--networkd-3B4252?style=flat-square)](https://www.freedesktop.org/software/systemd/man/latest/systemd-networkd.html)
[![iwd](https://img.shields.io/badge/iwd-3B4252?style=flat-square)](https://iwd.wiki.kernel.org/)
[![ClamAV](https://img.shields.io/badge/ClamAV-3B4252?style=flat-square)](https://www.clamav.net/)
[![OpenRGB](https://img.shields.io/badge/OpenRGB-3B4252?style=flat-square)](https://openrgb.org/)
[![snapper](https://img.shields.io/badge/snapper-3B4252?style=flat-square)](http://snapper.io/)
[![restic](https://img.shields.io/badge/restic-3B4252?style=flat-square)](https://restic.net/)
[![ufw](https://img.shields.io/badge/ufw-3B4252?style=flat-square)](https://launchpad.net/ufw)
[![gpu-screen-recorder](https://img.shields.io/badge/gpu--screen--recorder-3B4252?style=flat-square)](https://git.dec05eba.com/gpu-screen-recorder/about/)
[![WirePlumber](https://img.shields.io/badge/WirePlumber-3B4252?style=flat-square)](https://pipewire.pages.freedesktop.org/wireplumber/)
[![LACT](https://img.shields.io/badge/LACT-ED1C24?style=flat-square&logo=amd&logoColor=white)](https://github.com/ilya-zlobintsev/LACT)
[![RyzenAdj](https://img.shields.io/badge/RyzenAdj-ED1C24?style=flat-square&logo=amd&logoColor=white)](https://github.com/FlyGoat/RyzenAdj)
<!-- Tooling -->
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![GNU Stow](https://img.shields.io/badge/GNU%20Stow-A42E2B?style=flat-square&logo=gnu&logoColor=white)](https://www.gnu.org/software/stow/)
[![C](https://img.shields.io/badge/C-A8B9CC?style=flat-square&logo=c&logoColor=white)](https://en.cppreference.com/w/c)
<!-- Version -->
[![Version](https://img.shields.io/badge/Version-1.0.7.0-blue?style=flat-square)](CHANGELOG.md)
<!-- License and status -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)](#)

Hyprland rice: sharp corners, glass, switchable themes, each dark one with a light sibling (Harbour: navy/orange · Mono: black/white · Dusk: black/blue). See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.lua` → `lua/*.lua`; the pre-0.55 `hyprland.conf` → `conf.d/*.conf` set is kept as a fallback, `./restore.sh hypr` swaps between them), hyprlock, hypridle, hyprsunset (night light schedule: 4500 K from 19:00, 3500 K from 22:30, off from 06:30; the panel toggle overrides it until the next step) |
| `waybar/`  | status bar (Waybar git master). SUPER+SHIFT+V cycles the song visualiser while music plays: off, compact (bars beside the song), wide (the workspaces move left and the bars fill the centre), full (thin bars under the whole bar, drawn by Quickshell); also a quick toggle in the widget panel (`qs ipc call panel viz`, or `vizmode off|compact|wide|full`). cava runs only while a player is playing |
| `rofi/`    | launcher / menus: apps (SUPER+Space), emoji (SUPER+., rofimoji, copies), calculator (SUPER+C, rofi-calc, Enter copies), and `actions` (SUPER+X): theme, wallpaper, clipboard, screenshot, recording, snapshot, firewall, Wi-Fi, DNS, permissions, reload and restart, power |
| `quickshell/` | Quickshell: notification server, popups + centre (`qs ipc call notifs toggle|dnd|clear|status`) and the widget panel, on the anchor button / SUPER+A (`qs ipc call panel toggle|mediabar|status`): app search, quick toggles, CPU thermal-limit slider (`pkexec cpu-tctl`), media, system card (GPU via LACT), lighting (with a Themes button that opens the theme window), ClamAV status. Clicking the date on the bar drops down a month calendar (`qs ipc call calendar open|close|toggle`). Alt-Tab is a Quickshell switcher too: all windows with live thumbnails, release Alt to jump to one on its own workspace (`qs ipc call switcher next|prev|apply|cancel`). An on-screen display at the bottom centre shows volume and mute and microphone mute as PipeWire reports them (keys, panel and pavucontrol alike), plus Caps Lock and brightness from their binds (`qs ipc call osd caps|brightness`). `Theme.qml` is rendered by `theme` and hot-reloads. SUPER+SHIFT+T opens the theme window: a preview card per theme (its wallpaper under a mock desktop in its colours), dark and light halves side by side; a click applies it (`qs ipc call themes open|close|toggle`). SUPER+SHIFT+M opens the tray window over the windows hidden with SUPER+M: a click or Enter brings one back to the current workspace, the close button on its right or Delete closes it without bringing it forward (`qs ipc call tray open|close|toggle`) |
| `wlogout/` | power menu                                       |
| `kitty/`   | terminal                                         |
| `fish/`    | shell + starship prompt                          |
| `thunar/`  | file manager: right-click actions (Open Terminal Here in kitty, Open in VS Code, Copy Path, Set as Wallpaper via `wall`) and the preferences in `thunar.xfconf`, which install.sh writes with `xfconf-query` (xfconf also stores window state, so the file itself is not linked). It is the default for folders and answers 'show in folder' from other apps (a user D-Bus service for `org.freedesktop.FileManager1`). Thumbnails come from tumbler, Extract/Compress from thunar-archive-plugin with ark. Styling follows the GTK theme |
| `scripts/` | helpers in `~/.local/bin` (`clip`: clipboard history on SUPER+V with image thumbnails; `screenrec`: gpu-screen-recorder on ALT+Print (area), ALT+SHIFT+Print (screen), SUPER+ALT+Print (window), CTRL+ALT+Print (area with mic), the same key again stops, saved to `~/Videos/Recordings` with a red timer on the bar; SUPER+SHIFT+R keeps a 60 s instant replay, SUPER+ALT+R saves it; `theme`, `wall`, `shot` (Print area, SHIFT+Print screen, SUPER+Print window: copied to the clipboard straight away, satty waits in the tray for annotating, SUPER+SHIFT+M), `gpu-status`, `weather`, `keyhint`, `wifi`, `net`, `perms`, `snap`, `fw`, `doctor`, `backup`) |
| `themes/`  | `*.theme` colour files + `templates/` rendered by `theme`. Besides the desktop it colours btop (selects its `dotfiles` theme), VS Code (`workbench.colorCustomizations` in settings.json, applied live; the rest of the file is kept) and Firefox (`userChrome.css` in each profile plus the user.js pref that enables it; a userChrome.css that is not ours is left alone) and Vesktop (`dotfiles.theme.css` in its themes folder, enabled once in its settings: colours, small corner radii and the theme fonts, applied live). btop and Firefox take it on next start |
| `fonts/`   | Oxanium (UI), Quantico (display), Share Tech Mono (terminal), all OFL; JetBrainsMono Nerd Font supplies icons |
| `wallpapers/` | default wallpaper (linked into `~/Pictures/Wallpapers` by install.sh) |
| `sddm/`    | login screen (own Qt6 QML: blurred wallpaper, centred card); `sudo ./sddm/install-sddm.sh` once, then it follows `theme set` via `/var/lib/dotfiles-sddm` |
| `network/` | systemd-networkd + iwd + systemd-resolved in place of NetworkManager: `sudo ./network/install-network.sh` (`--nm` switches back). DNS has one setting for Ethernet and one for Wi-Fi (every Wi-Fi network), edited in the DNS settings window (panel DNS card, or `qs ipc call dns open`): IPv4 and IPv6 each Automatic (the network's own, i.e. the ISP's) or your servers, IPv6 can be switched off per connection, plus the DNS-over-TLS server name. `dns-set` writes it as a networkd drop-in and clears any temporary `resolvectl dns` servers on that connection; the window says whether the connection took it, and a connection that is switched off stays off (the setting applies when it is switched on). The profile ID never enters the repo. The Ethernet and Wi-Fi toggles use `net`. Wi-Fi picker: `wifi` (SUPER+SHIFT+W, the bar's network icon, or right-click the panel's Wi-Fi toggle) |
| `openrgb/` | `openrgb.service` (headless server, re-applies the saved preset at login) + `rgb` script; the panel's Lighting row switches presets (`~/.config/OpenRGB/profiles/*.json`) |
| `clamav/` | ClamAV on-access scanning: a blocking tier on Downloads and the other inbound folders, a detect tier on the rest of `~`, a weekly full scan, desktop notifications and a watchdog. `sudo ./clamav/install-clamav.sh` once (it also builds the shim that makes clamonacc work on glibc 2.44), `sudo ./clamav/apply.sh` after editing `clamav/stage/`. The panel's ClamAV card has a master switch and a switch for every unit. Details in [`clamav/README.md`](clamav/README.md) |
| `perms/` | Permissions window (Waybar shield, or `qs ipc call perms open`): microphone, screen sharing and background clipboard reading can be blocked per app or switched off for all; camera, audio capture (an app recording what is playing, such as cava), network, file access, notifications and background apps are shown. `perms` (in `scripts/`) keeps the rules in `~/.local/state/perms/` and turns them into WirePlumber permission managers (mic, portal screen shares), Hyprland screencopy permissions, and a launch gate (`perms run`, used by rofi and the app binds) that starts a clipboard-blocked app inside a Wayland security context, where Hyprland hides the clipboard data-control protocols. Old X11 apps and apps started from a terminal are not covered. `sudo ./perms/install-perms.sh` once: it builds that launcher and installs `perms-filed`, a fanotify service that records which app opens files in which folder of `~` (watch only). Tests: `python3 -B -m unittest discover -s perms/test` |
| `snapper/` | Btrfs snapshots of `/`: `sudo ./snapper/install-snapper.sh` sets up snapper's root config (hourly timeline, 5 hourly, 7 daily, 4 weekly), snap-pac (a pre/post pair around every pacman transaction) and grub-btrfs (a GRUB submenu to boot any snapshot), and lets the wheel group list and take snapshots without root. `snap now|list|status|gui` in `scripts/`; the panel's Safeguards card shows the last snapshot, takes one and opens btrfs-assistant. `/home` is not snapshotted (game libraries churn too much there) |
| `firewall/` | ufw: `sudo ./firewall/install-firewall.sh` drops all inbound traffic except KDE Connect (1714-1764 tcp+udp) from private LAN ranges, and leaves rules added by hand alone. `fw on|off|status|log` in `scripts/`; the Safeguards card has a switch (pkexec), the allow-rule count, packets blocked this boot and the block log |
| `backup/` | restic backup of `~`: `sudo ./backup/install-backup.sh LABEL=<label>` installs restic and adds an fstab automount for the backup partition at `/mnt/backup` (NTFS through ntfs3, a missing drive never blocks boot); then `backup init` creates the repository with a random password in `~/.config/restic` (copy it somewhere off this disk) and enables a daily timer. Games, caches, toolchains and build output are left out (`backup/excludes.txt`); snapshots are thinned to 7 daily, 4 weekly, 6 monthly. A run is skipped when the drive is absent, and refused when the mount point is not really mounted. `backup run|status|snapshots|browse`; the Safeguards card shows the last run and has Back up now |
| `pacman/` | `sudo ./pacman/install-hooks.sh`: a hook that lists the checks to run after Hyprland, Quickshell, hyprlock or hypridle upgrade (both change config syntax often), a hook that rebuilds the clamonacc fts shim whenever glibc or clamav changes, and `paccache.timer` (keeps 3 versions of each package in the cache) |
| KDE Connect | phone pairing, notifications, shared clipboard and file transfer: `kdeconnect` in packages.txt, its tray indicator (which starts the daemon) from Hyprland's autostart, the phone app from the actions menu (SUPER+X), and its ports (1714-1764, LAN only) opened by `firewall/` |
| `amd/`     | `sudo ./amd/install-lact.sh`: LACT (GPU clocks/power/fans GUI + daemon) and the `amdgpu.ppfeaturemask` kernel parameter that unlocks overdrive; reboot after. `amd/ryzen.conf` + `sudo ./amd/install-ryzenadj.sh`: CPU thermal/PPT/Curve-Optimizer limits via RyzenAdj (AUR), re-applied at boot and after resume; also installs `cpu-tctl`, which the panel's slider calls through polkit |
| `test/`    | `nested.sh`: try the config in a window; `lint.sh`: ShellCheck, `luac -p` on the Lua config, the perms tests and `secrets.sh`, the same checks CI runs on every push; `secrets.sh` refuses AdGuard profile IDs and private keys, and runs as the pre-commit hook (`.githooks/`, set by install.sh) |

## Workflow
1. Edit files in the repo.
2. `./test/nested.sh` to try them in a nested Hyprland window.
3. `./install.sh` (stow) to deploy for real (re-run `./install.sh scripts` after adding a new script, since `~/.local/bin` is linked per file). Existing configs are moved to `~/.local/state/dotfiles-backup/` first; `./restore.sh` reverses it (only useful right after a first install; once you live on these dotfiles, fix a broken login with `./install.sh`, not `restore.sh`). Hyprland reloads its Lua config on save (`hyprctl reload` forces it). `hyprctl dispatch` takes Lua now (`hyprctl dispatch 'hl.dsp.exit()'`); scripts use `~/.local/bin/hdsp 'LUA' LEGACY…` so they also work on the fallback config. `hyprctl repl` is a live Lua prompt; SUPER+/ lists every bind with its description.
4. `doctor` checks the result: links, packages, theme files, session units, Hyprland config errors, Quickshell IPC, the pre-commit hook and each optional system part, with the fix for anything wrong.
5. Commit.

## Fresh machine
```sh
sudo pacman -S --needed --asexplicit - < packages.txt
sudo ./snapper/install-snapper.sh # optional; snapshots of / around every update
sudo ./firewall/install-firewall.sh # optional; inbound default-deny
sudo ./pacman/install-hooks.sh    # optional; post-upgrade checks, shim rebuild, cache cleaning
sudo ./clamav/install-clamav.sh   # optional; before ./install.sh, which links the ClamAV user units only if ClamAV is there
./install.sh
sudo ./perms/install-perms.sh     # optional; clipboard blocking and the file access history in the permissions window
```

## License

Copyright © 2026 Sricharan Suresh (github.com/verycareful)

Released under the **[MIT License](LICENSE)**. You may use, copy, modify, merge, publish, distribute, sublicense and
sell copies, in whole or in part, for any purpose, commercial included. The one condition: keep the copyright notice
and the permission notice in all copies or substantial portions. It comes with no warranty of any kind, and the
author is not liable for anything arising from its use.

Bundled third-party files keep their own licences:
- `fonts/`: Oxanium, Quantico and Share Tech Mono, under the SIL Open Font License 1.1 (each folder carries its `OFL.txt`).
- `wallpapers/`: see [`wallpapers/CREDITS.md`](wallpapers/CREDITS.md).
- `clamav/stage/etc/clamav/clamd.conf`: ClamAV's sample configuration with local settings, GPL-2.0.
