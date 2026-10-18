#!/usr/bin/env bash
# pacman hooks and cache cleaning. Run as root:  sudo ./pacman/install-hooks.sh   (again after editing pacman/)
#   50-dotfiles-desktop-updated   after hyprland/quickshell/hyprlock/hypridle upgrades, prints the checks to run
#   60-dotfiles-clamonacc-shim    rebuilds the clamonacc fts shim when glibc or clamav changes
#   paccache.timer                weekly: keep the last 3 versions of each package in the cache
# snap-pac's pre/post snapshots come from snapper/install-snapper.sh.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
S="$(cd "$(dirname "$0")" && pwd)"

pacman -S --needed --noconfirm --asexplicit pacman-contrib
install -v -Dm755 -t /usr/local/lib/dotfiles "$S/bin/desktop-updated" "$S/bin/rebuild-fts-shim"
install -v -Dm644 -t /etc/pacman.d/hooks "$S"/hooks/*.hook
install -v -Dm644 "$S/../clamav/fts-shim/clamonacc-fts-shim.c" /usr/local/src/dotfiles/clamonacc-fts-shim.c
systemctl enable --now paccache.timer
