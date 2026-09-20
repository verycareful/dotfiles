#!/usr/bin/env bash
# Undo install.sh: remove our symlinks and put the backed-up configs back.
#   ./restore.sh              use the newest backup
#   ./restore.sh <backupdir>  use that one
#   ./restore.sh hypr         swap the Hyprland config between Lua (hyprland.lua) and the
#                             legacy hyprlang set (hyprland.conf + conf.d/). Pure rename,
#                             nothing is overwritten; run it again to swap back.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" == "hypr" ]]; then
    # Hyprland loads hyprland.lua when it exists, else hyprland.conf. Both sets live in the
    # repo (~/.config/hypr is a symlink to it), so "swapping" = renaming the Lua entry file.
    # While on the legacy set, git shows hyprland.lua as deleted — that's the reminder.
    cfg="$HOME/.config/hypr"
    if [[ -e "$cfg/hyprland.lua" ]]; then
        mv "$cfg/hyprland.lua" "$cfg/hyprland.lua.disabled"
        echo "Hyprland config: LEGACY (hyprland.conf). Log out and back in to apply —"
        echo "a live 'hyprctl reload full-reset' from Lua to hyprlang crashes Hyprland 0.56."
    elif [[ -e "$cfg/hyprland.lua.disabled" ]]; then
        mv "$cfg/hyprland.lua.disabled" "$cfg/hyprland.lua"
        echo "Hyprland config: LUA (hyprland.lua)."
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && ! [[ "$(hyprctl repl 'hl.version()' 2>/dev/null)" =~ ^[0-9] ]]; then
            hyprctl reload full-reset >/dev/null && echo "applied live (hyprctl reload full-reset)."
        fi
    else
        echo "neither $cfg/hyprland.lua nor hyprland.lua.disabled exists" >&2; exit 1
    fi
    exit 0
fi
BK="${1:-$(ls -d "$HOME"/.local/state/dotfiles-backup/[0-9]*/ 2>/dev/null | sort | tail -1)}"   # newest DATED backup
[[ -n "$BK" && -d "$BK" ]] || { echo "no backup found" >&2; exit 1; }
./install.sh -D
(cd "$BK" && { find .config -mindepth 1 -maxdepth 1 2>/dev/null; find . -path ./.config -prune -o -type f -print; } | sed 's#^\./##') | while IFS= read -r rel; do
    mkdir -p "$HOME/$(dirname "$rel")"
    if [[ -d "$BK/$rel" && -d "$HOME/$rel" ]]; then      # target dir exists: merge, don't nest
        cp -a "$BK/$rel/." "$HOME/$rel/" && rm -rf "$BK/$rel" && echo "merged $rel"
    else
        mv -v "$BK/$rel" "$HOME/$rel"
    fi
done
echo "restored from $BK — log out and back in."
