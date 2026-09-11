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
    # Conflict units: whole dirs under .config (e.g. .config/hypr), but single
    # files elsewhere (.local/bin/wall) since those dirs are shared with other tools.
    while IFS= read -r rel; do
        target="$HOME/$rel"
        [[ -e "$target" || -L "$target" ]] || continue
        # already a symlink into this repo → nothing to do
        [[ -L "$target" && "$(readlink -f "$target")" == "$REPO"/* ]] && continue
        mkdir -p "$BK/$(dirname "$rel")"
        mv -v "$target" "$BK/$rel"
    done < <(cd "$1" && { find .config -mindepth 1 -maxdepth 1 2>/dev/null; find . -path ./.config -prune -o -type f -print; } | sed 's#^\./##')
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

# libadwaita/GTK4 apps read these from gsettings rather than settings.ini
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
    gsettings set org.gnome.desktop.interface font-name 'Oxanium Medium 10'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Share Tech Mono 11'
fi

echo "done. Log out and back in for Hyprland to pick up the new config."
