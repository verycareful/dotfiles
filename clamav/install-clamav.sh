#!/usr/bin/env bash
# ClamAV clean install with two-tier on-access scanning. Run as root.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Installing clamav (+ gcc for the shim, socat for the watchdog's STATS query)"
pacman -S --needed --noconfirm clamav gcc socat
systemd-tmpfiles --create clamav.conf   # /run/clamav /var/log/clamav /var/lib/clamav

step "Building and installing the fts shim for clamonacc (glibc >= 2.44 workaround, see fts-shim/)"
gcc -O2 -fPIC -shared -Wall -o "$S/fts-shim/clamonacc-fts-shim.so" "$S/fts-shim/clamonacc-fts-shim.c" -ldl
install -v -Dm644 -o root -g root "$S/fts-shim/clamonacc-fts-shim.so" /usr/local/lib/clamonacc-fts-shim.so

step "Installing configuration"
install -v -Dm644 "$S/stage/etc/clamav/clamd.conf"            /etc/clamav/clamd.conf
install -v -Dm644 "$S/stage/etc/clamav/clamonacc-block.conf"  /etc/clamav/clamonacc-block.conf
install -v -Dm644 "$S/stage/etc/clamav/clamonacc-notify.conf" /etc/clamav/clamonacc-notify.conf
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-clamonacc@.service" /etc/systemd/system/clamav-clamonacc@.service
install -v -Dm644 "$S/stage/etc/sysctl.d/60-clamav-onaccess.conf" /etc/sysctl.d/60-clamav-onaccess.conf
install -v -Dm755 "$S/stage/usr/local/bin/clamav-watchdog" /usr/local/bin/clamav-watchdog
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-watchdog.service" /etc/systemd/system/clamav-watchdog.service
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-watchdog.timer"   /etc/systemd/system/clamav-watchdog.timer
sysctl -q -p /etc/sysctl.d/60-clamav-onaccess.conf && sysctl fs.inotify.max_user_watches

step "Quarantine directory (root-only; outside /home so it can never be re-scanned)"
install -d -m700 -o root -g root /var/lib/clamav/quarantine
if [ -d /root/quarantine ]; then
    rm -f /root/quarantine/.clamav-quarantine-lock.*          # stale lock files, junk
    find /root/quarantine -mindepth 1 -maxdepth 1 -exec mv -v -t /var/lib/clamav/quarantine/ {} +
    rmdir -v /root/quarantine
fi
ls -la /var/lib/clamav/quarantine

step "Stock single-instance clamonacc unit is replaced by the template: masking it"
systemctl daemon-reload
systemctl mask clamav-clamonacc.service

step "Signature database"
if ls /var/lib/clamav/main.c[vl]d >/dev/null 2>&1; then
    echo "existing DB found, running freshclam to bring it current"
else
    echo "no DB: initial download (~110 MB)"
fi
freshclam || echo "freshclam exit $? (a 'NotifyClamd' warning here is expected, clamd isn't up yet)"
ls -la /var/lib/clamav/*.cvd

step "Enabling and starting services"
systemctl enable --now clamav-freshclam.service clamav-daemon.socket clamav-daemon.service
systemctl enable --now clamav-clamonacc@block.service clamav-clamonacc@notify.service
systemctl enable --now clamav-watchdog.timer

step "Status"
sleep 3
systemctl --no-pager --no-legend list-units 'clamav*'
echo; echo "install done. clamd takes ~20-40 s to load signatures; clamonacc waits for it."
