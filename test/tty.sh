#!/usr/bin/env bash
# Run the repo config as a REAL Hyprland session from a text console (TTY),
# without installing anything. Your normal desktop keeps running on its own
# TTY — Ctrl+Alt+F1 (or wherever it is) switches back to it at any time.
#
#   1. Ctrl+Alt+F3  → log in
#   2. ~/Sonnenplatz/Projects/Github/dotfiles/test/tty.sh
#   3. SUPER+Shift+Q exits; the log path is printed afterwards.
set -euo pipefail
if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
    echo "This is running inside a graphical session, so Hyprland would start as a nested" >&2
    echo "window and your current desktop would keep every SUPER keybind." >&2
    echo "Press Ctrl+Alt+F3, log in at the text prompt, and run it there." >&2
    exit 1
fi
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${XDG_RUNTIME_DIR:-/tmp}/hypr-tty"
rm -rf "$TMP"; mkdir -p "$TMP/config"
LOG="$REPO/test/tty-last.log"

# Hyprland config: repo copy with paths rewritten to the temp dir
cp -r "$REPO/hypr/.config/hypr/." "$TMP/"
sed -i "s#~/.config/hypr/#$TMP/#g" "$TMP/hyprland.conf" "$TMP/hyprlock.conf"
# always have a terminal on screen so the session is never "empty"
echo 'exec-once = kitty' >> "$TMP/hyprland.conf"
# user units would bind to the login session's Wayland display, so run those programs directly here
python3 - "$TMP/conf.d/autostart.conf" <<'PY'
import sys, re
p = sys.argv[1]; out = []
for line in open(p):
    m = re.match(r'exec-once = systemctl --user start (.*)', line.strip())
    if m:
        for unit in m.group(1).split():
            out.append('exec-once = ' + ('/usr/lib/hyprpolkitagent' if unit == 'hyprpolkitagent' else unit) + '\n')
    else:
        out.append(line)
open(p, 'w').write(''.join(out))
PY

# every other tool reads its config from XDG_CONFIG_HOME → temp copies
for pkg in waybar rofi kitty swaync wlogout fastfetch; do
    cp -r "$REPO/$pkg/.config/$pkg" "$TMP/config/$pkg"
done
cp -r "$REPO/gtk/.config/." "$TMP/config/"
cp -r "$REPO/qt/.config/."  "$TMP/config/"
grep -rl '~/.local/bin/' "$TMP" | xargs -r sed -i "s#~/.local/bin/#$REPO/scripts/.local/bin/#g"

export XDG_CONFIG_HOME="$TMP/config"
# render the colour files for the current theme into the temp copies
ln -sfn "$TMP" "$TMP/config/hypr"
XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/state" "$REPO/scripts/.local/bin/theme" set "$(cat "$HOME/.local/state/theme/current" 2>/dev/null || echo harbour)" --no-reload >/dev/null

export PATH="$REPO/scripts/.local/bin:$PATH"
export WALL_DIR="$REPO/wallpapers"
export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=Hyprland

echo "starting Hyprland with $TMP/hyprland.conf — log: $LOG"
Hyprland -c "$TMP/hyprland.conf" >"$LOG" 2>&1 || true
echo
echo "session ended. errors/warnings from the log:"
grep -iE 'err|warn|fail|crit|not found|no such' "$LOG" | grep -vE 'xkbcomp|Warning: +(Symbol|Multiple|Could not resolve|Virtual|Unsupported)|Using (last|F23|0)|X11 cannot' | head -30 || true
echo "full log: $LOG"
