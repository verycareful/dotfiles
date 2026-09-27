#!/usr/bin/env bash
# ClamAV clean-slate removal. Run as root.
# Keeps the signature database (/var/lib/clamav/*.cvd) by default: it's data,
# not config, and re-downloading 110 MB risks the CDN rate limit. KEEP_DB=0 to nuke it.
set -uo pipefail
KEEP_DB="${KEEP_DB:-1}"
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Stopping and disabling ClamAV services"
systemctl disable --now clamav-watchdog.timer clamav-clamonacc@block.service clamav-clamonacc@notify.service \
    clamav-clamonacc.service clamav-daemon.service clamav-daemon.socket \
    clamav-freshclam.service clamav-freshclam-once.timer 2>&1 | grep -v 'does not exist' || true
systemctl unmask clamav-clamonacc.service 2>/dev/null || true
systemctl reset-failed 'clamav-*' 2>/dev/null || true

step "Contents of old quarantine (/root/quarantine): preserved, migrated by install-clamav.sh"
ls -la /root/quarantine 2>/dev/null || echo "(none)"

step "Removing package (clamav + orphaned deps libmspack, libmilter; -n also drops tracked configs)"
pacman -Rns --noconfirm clamav

step "Removing leftover config, logs, runtime, overrides, sudoers rule, and what install-clamav.sh added"
rm -rfv /etc/clamav /var/log/clamav /run/clamav \
        /etc/systemd/system/clamav-clamonacc.service.d \
        /etc/sudoers.d/clamav-notify \
        /etc/systemd/system/clamav-clamonacc@.service \
        /etc/systemd/system/clamav-watchdog.service /etc/systemd/system/clamav-watchdog.timer \
        /usr/local/bin/clamav-watchdog /usr/local/lib/clamonacc-fts-shim.so \
        /etc/sysctl.d/60-clamav-onaccess.conf /run/clamav-watchdog.strikes
if [ "$KEEP_DB" = "0" ]; then
    rm -rfv /var/lib/clamav
else
    rm -fv /var/lib/clamav/freshclam.dat /var/lib/clamav/*.cld /var/lib/clamav/mirrors.dat 2>/dev/null
    echo "kept signature DB:"; ls -la /var/lib/clamav/ 2>/dev/null || echo "(none)"
fi
systemctl daemon-reload

step "Verification: all of these should be empty / 'not found'"
pacman -Q clamav 2>&1
ls -la /etc/clamav /var/log/clamav 2>&1
systemctl list-unit-files 'clamav*' --no-legend 2>&1
pgrep -a clam || echo "no clam* processes running"
echo; echo "cleanup done."
