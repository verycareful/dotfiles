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

# Build a throwaway config: the repo's, with the nested-only overrides appended.
# (Nested Hyprland exposes one virtual monitor named WL-1; scripts in the repo
#  are made visible via PATH so autostart finds them.)
cat "$REPO/hypr/.config/hypr/hyprland.conf" > "$TMP/hyprland.conf"
sed -i "s#~/.config/hypr/#$REPO/hypr/.config/hypr/#g" "$TMP/hyprland.conf"
cat >> "$TMP/hyprland.conf" <<CONF

# ── nested-only overrides ──
monitor = WL-1, ${W}x${H}, 0x0, 1
exec-once = kitty
CONF

export PATH="$REPO/scripts/.local/bin:$PATH"
export XDG_CONFIG_HOME="$TMP/config"      # so waybar/rofi/etc pick up repo copies
mkdir -p "$TMP/config"
for pkg in waybar rofi kitty swaync; do
    [[ -d "$REPO/$pkg/.config/$pkg" ]] && ln -s "$REPO/$pkg/.config/$pkg" "$TMP/config/$pkg"
done

echo "config: $TMP/hyprland.conf"
echo "Focus the nested window, then use SUPER+... inside it. Close it to quit."
Hyprland -c "$TMP/hyprland.conf"
rm -rf "$TMP"
