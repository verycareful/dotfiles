#!/usr/bin/env bash
# Launch a NESTED Hyprland using the repo config, as a window inside the
# current session. Nothing in ~/.config is touched. Close the window to exit.
#
#   ./test/nested.sh           # 1600x900 window
#   ./test/nested.sh 1920 1080
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W="${1:-1600}"; H="${2:-900}"
TMP="$(mktemp -d /tmp/hypr-nested.XXXX)"

# Build a throwaway copy of the config with nested-only tweaks:
#  - $mod becomes ALT, because the OUTER Hyprland grabs SUPER binds first and
#    they never reach the nested window. Inside the test window use ALT+…
#  - one virtual monitor (WL-1) at the requested size
#  - scripts in the repo are made visible via PATH so autostart finds them
cp -r "$REPO/hypr/.config/hypr/." "$TMP/"
sed -i "s#~/.config/hypr/#$TMP/#g" "$TMP/hyprland.conf"
sed -i 's/^\$mod *= *SUPER/$mod = ALT/' "$TMP/conf.d/binds.conf"
cat >> "$TMP/hyprland.conf" <<CONF

# ── nested-only overrides ──
monitor = WL-1, ${W}x${H}, 0x0, 1
exec-once = kitty
CONF

export PATH="$REPO/scripts/.local/bin:$PATH"
export WALL_DIR="$REPO/wallpapers"
export XDG_CONFIG_HOME="$TMP/config"      # so waybar/rofi/etc pick up repo copies
# render the colour files for the current theme into the temp copies
ln -sfn "$REPO/hypr/.config/hypr" "$TMP/config/hypr"
XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/state" "$REPO/scripts/.local/bin/theme" set "$(cat "$HOME/.local/state/theme/current" 2>/dev/null || echo harbour)" --no-reload >/dev/null

mkdir -p "$TMP/config"
for pkg in waybar rofi kitty swaync wlogout fastfetch; do
    [[ -d "$REPO/$pkg/.config/$pkg" ]] && cp -r "$REPO/$pkg/.config/$pkg" "$TMP/config/$pkg"
done
# configs reference ~/.local/bin/<script>; point them at the repo copies instead
grep -rl '~/.local/bin/' "$TMP" | xargs -r sed -i "s#~/.local/bin/#$REPO/scripts/.local/bin/#g"

echo "config: $TMP/hyprland.conf"
echo "Focus the nested window and use ALT+... inside it (ALT+Enter, ALT+Q, ALT+1…). Close it to quit."
Hyprland -c "$TMP/hyprland.conf"
rm -rf "$TMP"
