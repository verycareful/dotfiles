#!/usr/bin/env bash
# Undo install.sh: remove our symlinks and put the backed-up configs back.
#   ./restore.sh              use the newest backup
#   ./restore.sh <backupdir>  use that one
set -euo pipefail
cd "$(dirname "$0")"
BK="${1:-$(ls -d "$HOME"/.local/state/dotfiles-backup/*/ 2>/dev/null | sort | tail -1)}"
[[ -n "$BK" && -d "$BK" ]] || { echo "no backup found" >&2; exit 1; }
./install.sh -D
(cd "$BK" && { find .config -mindepth 1 -maxdepth 1 2>/dev/null; find . -path ./.config -prune -o -type f -print; } | sed 's#^\./##') | while IFS= read -r rel; do
    mkdir -p "$HOME/$(dirname "$rel")"
    mv -v "$BK/$rel" "$HOME/$rel"
done
echo "restored from $BK — log out and back in."
