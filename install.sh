#!/usr/bin/env bash
# Deploy the dotfiles with GNU Stow (symlinks ~/.config/X -> repo/X/.config/X).
# Anything already at a target path that is NOT ours is moved to
#   ~/.local/state/dotfiles-backup/<timestamp>/   (restore.sh puts it back)
#
#   ./install.sh            stow every package
#   ./install.sh hypr kitty stow only these
#   ./install.sh -D hypr    unstow (remove symlinks)
set -euo pipefail
cd "$(dirname "$0")"
REPO="$PWD"
ALL=(hypr waybar rofi kitty fish swaync wlogout gtk qt scripts)
op=""
[[ "${1:-}" == "-D" ]] && { op="-D"; shift; }
pkgs=("${@:-${ALL[@]}}")

command -v stow >/dev/null || { echo "stow is not installed: sudo pacman -S stow" >&2; exit 1; }

BK="$HOME/.local/state/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backup_conflicts() {                     # $1 = package dir
    # every path the package would create directly under $HOME (e.g. .config/hypr)
    while IFS= read -r rel; do
        target="$HOME/$rel"
        [[ -e "$target" || -L "$target" ]] || continue
        # already a symlink into this repo → nothing to do
        [[ -L "$target" && "$(readlink -f "$target")" == "$REPO"/* ]] && continue
        mkdir -p "$BK/$(dirname "$rel")"
        mv -v "$target" "$BK/$rel"
    done < <(cd "$1" && find . -mindepth 2 -maxdepth 2 -not -path './.git*' | sed 's#^\./##')
}

for p in "${pkgs[@]}"; do
    [[ -d "$p" ]] || { echo "skip $p (no such package dir)"; continue; }
    [[ -z "$op" ]] && backup_conflicts "$p"
    stow -v $op -t "$HOME" "$p"
done
[[ -d "$BK" ]] && echo "previous configs moved to: $BK  (restore.sh reverses this)"

[[ -n "$op" ]] && exit 0

# wallpapers: link the repo's into ~/Pictures/Wallpapers (add your own there too)
mkdir -p "$HOME/Pictures/Wallpapers"
for w in wallpapers/*; do ln -sfn "$PWD/$w" "$HOME/Pictures/Wallpapers/$(basename "$w")"; done

# fonts: Oxanium + Quantico + Share Tech Mono (OFL) from fonts/ into the user font dir
mkdir -p "$HOME/.local/share/fonts/dotfiles"
cp fonts/*/*.ttf "$HOME/.local/share/fonts/dotfiles/" && fc-cache -f

echo "done. Log out and back in for Hyprland to pick up the new config."
