# dotfiles

Hyprland rice — sharp corners, glass, switchable themes (Harbour: navy/orange · Mono: black/white). See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.conf` → `conf.d/*.conf`), hyprlock, hypridle |
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
| `test/`    | `nested.sh` — try the config in a window         |

## Workflow
1. Edit files in the repo.
2. `./test/nested.sh` to try them in a nested Hyprland window.
3. `./install.sh` (stow) to deploy for real — re-run `./install.sh scripts` after adding a new script, since `~/.local/bin` is linked per file — existing configs are moved to `~/.local/state/dotfiles-backup/` first; `./restore.sh` reverses it (only useful right after a first install — once you live on these dotfiles, fix a broken login with `./install.sh`, not `restore.sh`). `hyprctl reload` applies Hyprland changes live.
4. Commit.

## Fresh machine
```sh
sudo pacman -S --needed --asexplicit - < packages.txt
./install.sh
```

## License
MIT — see [LICENSE](LICENSE).
