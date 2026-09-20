# dotfiles

Hyprland rice — sharp corners, glass, switchable themes (Harbour: navy/orange · Mono: black/white). See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.lua` → `lua/*.lua`; the pre-0.55 `hyprland.conf` → `conf.d/*.conf` set is kept as a fallback, `./restore.sh hypr` swaps between them), hyprlock, hypridle |
| `waybar/`  | status bar                                       |
| `rofi/`    | launcher / menus                                 |
| `swaync/`  | notifications                                    |
| `wlogout/` | power menu                                       |
| `kitty/`   | terminal                                         |
| `fish/`    | shell + starship prompt                          |
| `scripts/` | helpers in `~/.local/bin` (`theme`, `wall`, `shot`, `gpu-status`, `weather`, `keyhint`) |
| `themes/`  | `*.theme` colour files + `templates/` rendered by `theme` |
| `fonts/`   | Oxanium (UI), Quantico (display), Share Tech Mono (terminal) — all OFL; JetBrainsMono Nerd Font supplies icons |
| `wallpapers/` | default wallpaper (linked into `~/Pictures/Wallpapers` by install.sh) |
| `sddm/`    | login screen (Corners-based); `sudo ./sddm/install-sddm.sh` |
| `amd/`     | `sudo ./amd/install-lact.sh` — LACT (GPU clocks/power/fans GUI + daemon) and the `amdgpu.ppfeaturemask` kernel parameter that unlocks overdrive; reboot after. `amd/ryzen.conf` + `sudo ./amd/install-ryzenadj.sh` — CPU thermal/PPT/Curve-Optimizer limits via RyzenAdj (AUR), re-applied at boot and after resume |
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
