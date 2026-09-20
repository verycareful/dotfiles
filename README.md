# dotfiles

Hyprland rice — sharp corners, glass, switchable themes (Harbour: navy/orange · Mono: black/white). See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.lua` → `lua/*.lua`; the pre-0.55 `hyprland.conf` → `conf.d/*.conf` set is kept as a fallback, `./restore.sh hypr` swaps between them), hyprlock, hypridle |
| `waybar/`  | status bar                                       |
| `rofi/`    | launcher / menus                                 |
| `quickshell/` | Quickshell: notification server, popups + centre (`qs ipc call notifs toggle|dnd|clear|status`) and the widget panel — anchor button / SUPER+A (`qs ipc call panel toggle|mediabar|status`): app search, quick toggles, CPU thermal-limit slider (`pkexec cpu-tctl`), media, system card (GPU via LACT), lighting, ClamAV status, calendar. Alt-Tab is a Quickshell switcher too: all windows with live thumbnails, release Alt to jump to one on its own workspace (`qs ipc call switcher next|prev|apply|cancel`). `Theme.qml` is rendered by `theme` and hot-reloads |
| `wlogout/` | power menu                                       |
| `kitty/`   | terminal                                         |
| `fish/`    | shell + starship prompt                          |
| `scripts/` | helpers in `~/.local/bin` (`theme`, `wall`, `shot`, `gpu-status`, `weather`, `keyhint`) |
| `themes/`  | `*.theme` colour files + `templates/` rendered by `theme` |
| `fonts/`   | Oxanium (UI), Quantico (display), Share Tech Mono (terminal) — all OFL; JetBrainsMono Nerd Font supplies icons |
| `wallpapers/` | default wallpaper (linked into `~/Pictures/Wallpapers` by install.sh) |
| `sddm/`    | login screen (own Qt6 QML: blurred wallpaper, centred card); `sudo ./sddm/install-sddm.sh` once, then it follows `theme set` via `/var/lib/dotfiles-sddm` |
| `openrgb/` | `openrgb.service` (headless server, re-applies the saved preset at login) + `rgb` script; the panel's Lighting row switches presets (`~/.config/OpenRGB/profiles/*.json`) |
| `amd/`     | `sudo ./amd/install-lact.sh` — LACT (GPU clocks/power/fans GUI + daemon) and the `amdgpu.ppfeaturemask` kernel parameter that unlocks overdrive; reboot after. `amd/ryzen.conf` + `sudo ./amd/install-ryzenadj.sh` — CPU thermal/PPT/Curve-Optimizer limits via RyzenAdj (AUR), re-applied at boot and after resume; also installs `cpu-tctl`, which the panel's slider calls through polkit |
| `test/`    | `nested.sh` — try the config in a window         |

## Workflow
1. Edit files in the repo.
2. `./test/nested.sh` to try them in a nested Hyprland window.
3. `./install.sh` (stow) to deploy for real — re-run `./install.sh scripts` after adding a new script, since `~/.local/bin` is linked per file — existing configs are moved to `~/.local/state/dotfiles-backup/` first; `./restore.sh` reverses it (only useful right after a first install — once you live on these dotfiles, fix a broken login with `./install.sh`, not `restore.sh`). Hyprland reloads its Lua config on save (`hyprctl reload` forces it). `hyprctl dispatch` takes Lua now (`hyprctl dispatch 'hl.dsp.exit()'`); scripts use `~/.local/bin/hdsp 'LUA' LEGACY…` so they also work on the fallback config. `hyprctl repl` is a live Lua prompt; SUPER+/ lists every bind with its description.
4. Commit.

## Fresh machine
```sh
sudo pacman -S --needed --asexplicit - < packages.txt
./install.sh
```

## License
MIT — see [LICENSE](LICENSE).
