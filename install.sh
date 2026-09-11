#!/usr/bin/env bash
# Deploy the dotfiles with GNU Stow (symlinks ~/.config/X -> repo/X/.config/X).
#   ./install.sh            stow every package
#   ./install.sh hypr kitty stow only these
#   ./install.sh -D hypr    unstow (remove symlinks)
set -euo pipefail
cd "$(dirname "$0")"
ALL=(hypr waybar rofi kitty fish swaync hyprlock scripts)
op=""
[[ "${1:-}" == "-D" ]] && { op="-D"; shift; }
pkgs=("${@:-${ALL[@]}}")
for p in "${pkgs[@]}"; do
    [[ -d "$p" ]] || { echo "skip $p (no such package dir)"; continue; }
    stow -v $op -t "$HOME" "$p"
done
