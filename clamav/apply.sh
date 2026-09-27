#!/usr/bin/env bash
# Re-apply everything in stage/ + the fts shim to the running system and restart the services.
# Use after editing any file under stage/. Root.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
gcc -O2 -fPIC -shared -Wall -o "$S/fts-shim/clamonacc-fts-shim.so" "$S/fts-shim/clamonacc-fts-shim.c" -ldl
install -v -Dm644 -o root -g root "$S/fts-shim/clamonacc-fts-shim.so" /usr/local/lib/clamonacc-fts-shim.so
install -v -Dm644 "$S/stage/etc/clamav/clamd.conf"            /etc/clamav/clamd.conf
install -v -Dm644 "$S/stage/etc/clamav/clamonacc-block.conf"  /etc/clamav/clamonacc-block.conf
install -v -Dm644 "$S/stage/etc/clamav/clamonacc-notify.conf" /etc/clamav/clamonacc-notify.conf
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-clamonacc@.service" /etc/systemd/system/clamav-clamonacc@.service
install -v -Dm644 "$S/stage/etc/sysctl.d/60-clamav-onaccess.conf" /etc/sysctl.d/60-clamav-onaccess.conf
install -v -Dm755 "$S/stage/usr/local/bin/clamav-watchdog" /usr/local/bin/clamav-watchdog
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-watchdog.service" /etc/systemd/system/clamav-watchdog.service
install -v -Dm644 "$S/stage/etc/systemd/system/clamav-watchdog.timer"   /etc/systemd/system/clamav-watchdog.timer
sysctl -q -p /etc/sysctl.d/60-clamav-onaccess.conf
systemctl daemon-reload
systemctl enable --now clamav-watchdog.timer >/dev/null
systemctl restart clamav-daemon.service clamav-clamonacc@block.service clamav-clamonacc@notify.service
echo "waiting for clamd to load signatures and the tiers to walk the tree..."; sleep 40
systemctl --no-pager --no-legend list-units 'clamav*'
for t in block notify; do echo; echo "=== $t tier ==="; journalctl -b -u "clamav-clamonacc@$t" --no-pager -o cat --since '-70s' | grep -vE '^-+$|^(Stopping|Stopped|Started) |exited, code=killed|Failed with result|Consumed'; done
