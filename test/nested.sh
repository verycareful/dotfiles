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
#  - mod becomes ALT, because the OUTER Hyprland grabs SUPER binds first and
#    they never reach the nested window. Inside the test window use ALT+…
#  - one virtual monitor (WAYLAND-1) at the requested size
#  - scripts in the repo are made visible via PATH so autostart finds them
# require("lua.x") resolves relative to hyprland.lua, so the copy needs no path edits.
cp -r "$REPO/hypr/.config/hypr/." "$TMP/"
sed -i 's/^local mod *= *"SUPER"/local mod = "ALT"/' "$TMP/lua/binds.lua"
cat >> "$TMP/hyprland.lua" <<LUA

-- ── nested-only overrides ──
hl.monitor({ output = "WAYLAND-1", mode = "${W}x${H}", position = "0x0", scale = 1 })
hl.on("hyprland.start", function() hl.exec_cmd("kitty") end)
LUA

export PATH="$REPO/scripts/.local/bin:$PATH"
export WALL_DIR="$REPO/wallpapers"
mkdir -p "$TMP/config"
export XDG_CONFIG_HOME="$TMP/config"      # so waybar/rofi/etc pick up repo copies
for pkg in waybar rofi kitty quickshell wlogout fastfetch; do
    [[ -d "$REPO/$pkg/.config/$pkg" ]] && cp -r "$REPO/$pkg/.config/$pkg" "$TMP/config/$pkg"
done
# render the colour files for the current theme into the temp copies
ln -sfn "$TMP" "$TMP/config/hypr"
XDG_STATE_HOME="$TMP/state" "$REPO/scripts/.local/bin/theme" set "$(cat "$HOME/.local/state/theme/current" 2>/dev/null || echo harbour)" --no-reload >/dev/null
# configs reference ~/.local/bin/<script>; point them at the repo copies instead
grep -rl '~/.local/bin/' "$TMP" | xargs -r sed -i "s#~/.local/bin/#$REPO/scripts/.local/bin/#g"

echo "config: $TMP/hyprland.lua"
echo "Focus the nested window and use ALT+... inside it (ALT+Enter, ALT+Q, ALT+1…). Close it to quit."
Hyprland -c "$TMP/hyprland.lua"
rm -rf "$TMP"
