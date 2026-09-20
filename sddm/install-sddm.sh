#!/usr/bin/env bash
# Install the login screen (needs sudo, once). After this, `theme set` updates it by itself:
# the theme's colour file and background live in /var/lib/dotfiles-sddm, owned by you, and the
# installed theme symlinks to them.
#   sudo ./sddm/install-sddm.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]] || { echo "run with sudo" >&2; exit 1; }
DST=/usr/share/sddm/themes/harbour
VAR=/var/lib/dotfiles-sddm
UHOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# theme files (static QML) + links into the user-writable dir
rm -rf "$DST"; mkdir -p "$DST"
cp "$REPO/sddm/harbour/"{Main.qml,metadata.desktop} "$DST/"
mkdir -p "$VAR"; chown "$SUDO_USER:$SUDO_USER" "$VAR"; chmod 755 "$VAR"
ln -sfn "$VAR/theme.conf" "$DST/theme.conf"
ln -sfn "$VAR/bg.jpg"     "$DST/bg.jpg"

# fonts must be system-wide for the sddm user
mkdir -p /usr/share/fonts/dotfiles && cp "$REPO"/fonts/*/*.ttf /usr/share/fonts/dotfiles/ && fc-cache -f >/dev/null

# render the active theme into $VAR as the user
sudo -u "$SUDO_USER" env HOME="$UHOME" WALL_DIR="${WALL_DIR:-$UHOME/Pictures/Wallpapers}" "$REPO/scripts/.local/bin/theme" sddm "$(cat "$UHOME/.local/state/theme/current" 2>/dev/null || echo harbour)" "$VAR"

# sddm config: our theme, Qt6 greeter, neutral cursor (the per-theme cursor applies after login)
mkdir -p /etc/sddm.conf.d
for f in /etc/sddm.conf.d/*hyde*.conf; do [[ -e "$f" ]] && mv -v "$f" "$f.disabled"; done
cat > /etc/sddm.conf.d/10-dotfiles.conf <<CONF
[Theme]
Current=harbour
CursorTheme=Bibata-Modern-Classic
CursorSize=24
CONF
echo "installed. Preview: sddm-greeter-qt6 --test-mode --theme $DST   (theme set keeps it in sync from now on)"
