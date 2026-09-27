# dotfiles
<!-- Platform -->
[![CachyOS](https://img.shields.io/badge/CachyOS-00B8A9?style=flat-square&logo=cachyos&logoColor=white)](https://cachyos.org/)
[![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=white)](https://wayland.freedesktop.org/)
<!-- Desktop -->
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=white)](https://hyprland.org/)
[![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org/)
[![Qt 6 QML](https://img.shields.io/badge/Qt%206%20QML-41CD52?style=flat-square&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qmlapplications.html)
<!-- Quickshell, Waybar, rofi, wlogout, SDDM, kitty, fastfetch, Kvantum, systemd-networkd, iwd, OpenRGB and ClamAV have no shields.io logos. Swap these plain badges for logo badges if logos become available. -->
[![Quickshell](https://img.shields.io/badge/Quickshell-3B4252?style=flat-square)](https://quickshell.org/)
[![Waybar](https://img.shields.io/badge/Waybar-3B4252?style=flat-square)](https://github.com/Alexays/Waybar)
[![rofi](https://img.shields.io/badge/rofi-3B4252?style=flat-square)](https://github.com/davatorium/rofi)
[![wlogout](https://img.shields.io/badge/wlogout-3B4252?style=flat-square)](https://github.com/ArtsyMacaw/wlogout)
[![SDDM](https://img.shields.io/badge/SDDM-3B4252?style=flat-square)](https://github.com/sddm/sddm)
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
[![LACT](https://img.shields.io/badge/LACT-ED1C24?style=flat-square&logo=amd&logoColor=white)](https://github.com/ilya-zlobintsev/LACT)
[![RyzenAdj](https://img.shields.io/badge/RyzenAdj-ED1C24?style=flat-square&logo=amd&logoColor=white)](https://github.com/FlyGoat/RyzenAdj)
<!-- Tooling -->
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![GNU Stow](https://img.shields.io/badge/GNU%20Stow-A42E2B?style=flat-square&logo=gnu&logoColor=white)](https://www.gnu.org/software/stow/)
[![C](https://img.shields.io/badge/C-A8B9CC?style=flat-square&logo=c&logoColor=white)](https://en.cppreference.com/w/c)
<!-- License and status -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)](#)

Hyprland rice: sharp corners, glass, switchable themes (Harbour: navy/orange · Mono: black/white). See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.lua` → `lua/*.lua`; the pre-0.55 `hyprland.conf` → `conf.d/*.conf` set is kept as a fallback, `./restore.sh hypr` swaps between them), hyprlock, hypridle |
| `waybar/`  | status bar                                       |
| `rofi/`    | launcher / menus                                 |
| `quickshell/` | Quickshell: notification server, popups + centre (`qs ipc call notifs toggle|dnd|clear|status`) and the widget panel, on the anchor button / SUPER+A (`qs ipc call panel toggle|mediabar|status`): app search, quick toggles, CPU thermal-limit slider (`pkexec cpu-tctl`), media, system card (GPU via LACT), lighting, ClamAV status, calendar. Alt-Tab is a Quickshell switcher too: all windows with live thumbnails, release Alt to jump to one on its own workspace (`qs ipc call switcher next|prev|apply|cancel`). `Theme.qml` is rendered by `theme` and hot-reloads |
| `wlogout/` | power menu                                       |
| `kitty/`   | terminal                                         |
| `fish/`    | shell + starship prompt                          |
| `scripts/` | helpers in `~/.local/bin` (`theme`, `wall`, `shot`, `gpu-status`, `weather`, `keyhint`, `wifi`, `net`) |
| `themes/`  | `*.theme` colour files + `templates/` rendered by `theme` |
| `fonts/`   | Oxanium (UI), Quantico (display), Share Tech Mono (terminal), all OFL; JetBrainsMono Nerd Font supplies icons |
| `wallpapers/` | default wallpaper (linked into `~/Pictures/Wallpapers` by install.sh) |
| `sddm/`    | login screen (own Qt6 QML: blurred wallpaper, centred card); `sudo ./sddm/install-sddm.sh` once, then it follows `theme set` via `/var/lib/dotfiles-sddm` |
| `network/` | systemd-networkd + iwd + systemd-resolved in place of NetworkManager: `sudo ./network/install-network.sh` (`--nm` switches back). DNS has one setting for Ethernet and one for Wi-Fi (every Wi-Fi network), edited in the DNS settings window (panel DNS card, or `qs ipc call dns open`): IPv4 and IPv6 each Automatic (the network's own, i.e. the ISP's) or your servers, IPv6 can be switched off per connection, plus the DNS-over-TLS server name. `dns-set` writes it as a networkd drop-in, so nothing else can override it; the profile ID never enters the repo. The Ethernet and Wi-Fi toggles use `net`. Wi-Fi picker: `wifi` (SUPER+SHIFT+W, the bar's network icon, or right-click the panel's Wi-Fi toggle) |
| `openrgb/` | `openrgb.service` (headless server, re-applies the saved preset at login) + `rgb` script; the panel's Lighting row switches presets (`~/.config/OpenRGB/profiles/*.json`) |
| `clamav/` | ClamAV on-access scanning: a blocking tier on Downloads and the other inbound folders, a detect tier on the rest of `~`, a weekly full scan, desktop notifications and a watchdog. `sudo ./clamav/install-clamav.sh` once (it also builds the shim that makes clamonacc work on glibc 2.44), `sudo ./clamav/apply.sh` after editing `clamav/stage/`. The panel's ClamAV card shows every unit with a switch. Details in [`clamav/README.md`](clamav/README.md) |
| `amd/`     | `sudo ./amd/install-lact.sh`: LACT (GPU clocks/power/fans GUI + daemon) and the `amdgpu.ppfeaturemask` kernel parameter that unlocks overdrive; reboot after. `amd/ryzen.conf` + `sudo ./amd/install-ryzenadj.sh`: CPU thermal/PPT/Curve-Optimizer limits via RyzenAdj (AUR), re-applied at boot and after resume; also installs `cpu-tctl`, which the panel's slider calls through polkit |
| `test/`    | `nested.sh`: try the config in a window         |

## Workflow
1. Edit files in the repo.
2. `./test/nested.sh` to try them in a nested Hyprland window.
3. `./install.sh` (stow) to deploy for real (re-run `./install.sh scripts` after adding a new script, since `~/.local/bin` is linked per file). Existing configs are moved to `~/.local/state/dotfiles-backup/` first; `./restore.sh` reverses it (only useful right after a first install; once you live on these dotfiles, fix a broken login with `./install.sh`, not `restore.sh`). Hyprland reloads its Lua config on save (`hyprctl reload` forces it). `hyprctl dispatch` takes Lua now (`hyprctl dispatch 'hl.dsp.exit()'`); scripts use `~/.local/bin/hdsp 'LUA' LEGACY…` so they also work on the fallback config. `hyprctl repl` is a live Lua prompt; SUPER+/ lists every bind with its description.
4. Commit.

## Fresh machine
```sh
sudo pacman -S --needed --asexplicit - < packages.txt
sudo ./clamav/install-clamav.sh   # optional; before ./install.sh, which links the ClamAV user units only if ClamAV is there
./install.sh
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
