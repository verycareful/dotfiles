#!/usr/bin/env bash
# ufw: drop everything inbound except what is listed here. Run as root:  sudo ./firewall/install-firewall.sh
# Idempotent: ufw skips a rule it already has, and rules added by hand are left alone.
#   KDE Connect  1714-1764 tcp+udp, from private LAN ranges only (phone pairing, file and clipboard sharing)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
LAN=(192.168.0.0/16 10.0.0.0/8 172.16.0.0/12)

pacman -S --needed --noconfirm --asexplicit ufw
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
for net in "${LAN[@]}"; do
    for proto in tcp udp; do
        ufw allow from "$net" to any port 1714:1764 proto "$proto" comment 'KDE Connect'
    done
done
ufw logging low
ufw --force enable
systemctl enable --now ufw.service
ufw status verbose
