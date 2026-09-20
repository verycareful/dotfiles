#!/usr/bin/env bash
# Persist the CPU limits in amd/ryzen.conf — needs sudo. Re-run after editing ryzen.conf.
#   yay -S ryzenadj              (AUR; once)
#   sudo ./amd/install-ryzenadj.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
command -v ryzenadj >/dev/null || { echo "ryzenadj not installed: yay -S ryzenadj" >&2; exit 1; }
install -m 644 "$REPO/amd/ryzen.conf" /etc/ryzenadj.conf
install -m 644 "$REPO/amd/ryzenadj-apply.service" /etc/systemd/system/ryzenadj-apply.service
install -m 755 "$REPO/amd/cpu-tctl" /usr/local/bin/cpu-tctl      # panel slider → pkexec cpu-tctl N
systemctl daemon-reload
systemctl enable ryzenadj-apply.service >/dev/null
systemctl restart ryzenadj-apply.service && echo "applied: $(sed -n 's/^RYZENADJ_ARGS=//p' /etc/ryzenadj.conf)"
