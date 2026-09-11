#!/usr/bin/env bash
# Install the login-screen theme (needs sudo). Re-run after changing themes/templates/sddm or the wallpaper.
#   sudo ./sddm/install-sddm.sh [theme-name]      default: the active theme
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-$(cat "${SUDO_USER:+/home/$SUDO_USER}/.local/state/theme/current" 2>/dev/null || echo harbour)}"
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
DST=/usr/share/sddm/themes/harbour

# theme files (QML from Corners) + rendered theme.conf + the active theme's wallpaper
mkdir -p "$DST/backgrounds"
cp -r "$REPO/sddm/harbour/"{Main.qml,components,icons,metadata.desktop} "$DST/"
"$REPO/scripts/.local/bin/theme" render "$REPO/themes/templates/sddm/theme.conf" "$NAME" > "$DST/theme.conf"
wp=$(sed -n 's/^wallpaper=//p' "$REPO/themes/$NAME.theme")
cp "$REPO/wallpapers/$wp" "$DST/backgrounds/bg.jpg"
cursor=$(sed -n 's/^cursor=//p' "$REPO/themes/$NAME.theme")

# fonts must be system-wide for the sddm user
mkdir -p /usr/share/fonts/dotfiles && cp "$REPO"/fonts/*/*.ttf /usr/share/fonts/dotfiles/ && fc-cache -f >/dev/null

# sddm config: ours replaces HyDE's (kept in the backup dir)
mkdir -p /etc/sddm.conf.d
for f in /etc/sddm.conf.d/*hyde*; do [[ -e "$f" ]] && mv -v "$f" "$f.disabled"; done
cat > /etc/sddm.conf.d/10-dotfiles.conf <<CONF
[Theme]
Current=harbour
CursorTheme=$cursor
CursorSize=24
CONF
echo "installed: theme '$NAME' colours into $DST. Log out to see it; 'sddm-greeter-qt6 --test-mode --theme $DST' previews it."
