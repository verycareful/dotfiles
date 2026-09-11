# dotfiles

Hyprland rice — dark navy, sharp corners, glass, orange accent. See `palette.md`.

| dir        | what                                             |
|------------|--------------------------------------------------|
| `hypr/`    | Hyprland (`hyprland.conf` → `conf.d/*.conf`), hyprlock, hypridle |
| `waybar/`  | status bar                                       |
| `rofi/`    | launcher / menus                                 |
| `swaync/`  | notifications                                    |
| `wlogout/` | power menu                                       |
| `kitty/`   | terminal                                         |
| `fish/`    | shell + starship prompt                          |
| `scripts/` | helpers in `~/.local/bin` (`wall`, `shot`, `gpu-status`, `weather`, `keyhint`) |
| `fonts/`   | Oxanium (UI), Quantico (display), Share Tech Mono (terminal) — all OFL; JetBrainsMono Nerd Font supplies icons |
| `wallpapers/` | default wallpaper (linked into `~/Pictures/Wallpapers` by install.sh) |
| `test/`    | `nested.sh` — try the config in a window         |

## Workflow
1. Edit files in the repo.
2. `./test/nested.sh` to try them in a nested Hyprland window.
3. `./install.sh` (stow) to deploy for real — existing configs are moved to `~/.local/state/dotfiles-backup/` first; `./restore.sh` reverses it. `hyprctl reload` applies Hyprland changes live.
4. Commit.

## Fresh machine
```sh
sudo pacman -S --needed - < packages.txt
./install.sh
```

## License
MIT — see [LICENSE](LICENSE).
