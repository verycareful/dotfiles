#!/usr/bin/env bash
# Root-side parts of the permissions window. Run with sudo from the user who owns the session:
#   sudo ./perms/install-perms.sh            install or update
# - /usr/local/bin/perms-sandbox: runs an app inside a Wayland security context (clipboard blocking)
# - /usr/local/bin/perms-filed + perms-filed@USER.service: file access watcher (fanotify)
# The user side (~/.local/bin/perms, Quickshell window, Waybar module) comes with ./install.sh.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
USER_NAME="${SUDO_USER:?run through sudo so the session user is known}"

step "Installing build tools (gcc, wayland, wayland-protocols)"
pacman -S --needed --noconfirm gcc wayland wayland-protocols

step "Building perms-sandbox (security-context-v1 launcher)"
XML=/usr/share/wayland-protocols/staging/security-context/security-context-v1.xml
B="$S/sandbox/build"
mkdir -p "$B"
wayland-scanner client-header "$XML" "$B/security-context-v1-client-protocol.h"
wayland-scanner private-code  "$XML" "$B/security-context-v1-protocol.c"
gcc -O2 -Wall -Wextra -I"$B" -o "$B/perms-sandbox" "$S/sandbox/perms-sandbox.c" "$B/security-context-v1-protocol.c" -lwayland-client
install -v -Dm755 -o root -g root "$B/perms-sandbox" /usr/local/bin/perms-sandbox
chown -R "$USER_NAME": "$B"

step "Installing the file access watcher"
install -v -Dm755 "$S/stage/usr/local/bin/perms-filed" /usr/local/bin/perms-filed
install -v -Dm644 "$S/stage/etc/systemd/system/perms-filed@.service" /etc/systemd/system/perms-filed@.service
systemctl daemon-reload
systemctl enable perms-filed@"$USER_NAME".service
systemctl restart perms-filed@"$USER_NAME".service

step "Status"
sleep 2
systemctl --no-pager --no-legend list-units 'perms-filed@*'
echo; echo "done. Open the permissions window (Waybar shield, or: qs ipc call perms open)."
