#!/usr/bin/env bash
# Networking: systemd-networkd (addressing) + iwd (Wi-Fi) + systemd-resolved (DNS), in place of
# NetworkManager. Needs sudo; re-run after editing anything in network/.
#   sudo ./network/install-network.sh         install / switch over
#   sudo ./network/install-network.sh --nm    back to NetworkManager (the escape hatch)
# DNS is per interface type, set in the DNS window (panel, DNS card; runs dns-set). A first install seeds both
# Ethernet and Wi-Fi from an old resolved.conf.d/adguard.conf if there is one, else Automatic.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
N="$REPO/network"
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }

if [[ "${1:-}" == "--nm" ]]; then
    systemctl disable --now iwd systemd-networkd systemd-networkd.socket systemd-networkd-wait-online 2>/dev/null || true
    rm -f /etc/systemd/network/{20-wired,25-wireless}.network
    systemctl enable --now NetworkManager NetworkManager-wait-online
    echo "back on NetworkManager. The panel's DNS card and toggles only drive networkd + iwd;"
    echo "for a GUI again: sudo pacman -S network-manager-applet"
    exit 0
fi
command -v iwctl >/dev/null || { echo "iwd is not installed: sudo pacman -S iwd" >&2; exit 1; }

install -Dm755 "$N/dns-set"             /usr/local/bin/dns-set
install -Dm644 "$N/20-wired.network"    /etc/systemd/network/20-wired.network
install -Dm644 "$N/25-wireless.network" /etc/systemd/network/25-wireless.network
install -Dm644 "$N/iwd.conf"            /etc/iwd/main.conf
install -Dm644 "$N/resolved.conf"       /etc/systemd/resolved.conf.d/10-dotfiles.conf
install -Dm644 "$N/wait-online.conf"    /etc/systemd/system/systemd-networkd-wait-online.service.d/dotfiles.conf
install -Dm644 "$N/network.rules"       /etc/polkit-1/rules.d/50-dotfiles-network.rules

# first run: carry the old global AdGuard servers over to both types, then drop the old files
old=/etc/systemd/resolved.conf.d/adguard.conf
for t in ethernet wifi; do
    [[ -e "/etc/systemd/network/$([[ $t == ethernet ]] && echo 20-wired || echo 25-wireless).network.d/50-dns.conf" ]] && continue
    servers=$(sed -n 's/^DNS=//p' "$old" 2>/dev/null | head -1)     # "ADDR#name ADDR#name"
    if [[ -n "$servers" ]]; then
        name=$(grep -oP '#\K[^ ]+' <<<"$servers" | head -1)
        /usr/local/bin/dns-set set "$t" --v4 "$(sed -E 's/#[^ ]+//g' <<<"$servers")" --v6 "" --tls yes --name "$name"
    else /usr/local/bin/dns-set set "$t"; fi
done
rm -f "$old" /etc/NetworkManager/conf.d/10-dotfiles-dns.conf
# NetworkManager's tray applet and connection editor do nothing without it
pacman -Q network-manager-applet &>/dev/null && { pacman -Rns --noconfirm network-manager-applet || true; }
ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# switch over. The network drops for a few seconds here.
systemctl daemon-reload
systemctl disable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher 2>/dev/null || true
systemctl stop wpa_supplicant 2>/dev/null || true          # NM's Wi-Fi backend; iwd owns wlan0 now
systemctl enable --now systemd-networkd.socket systemd-networkd iwd avahi-daemon
systemctl enable systemd-networkd-wait-online >/dev/null
systemctl restart systemd-resolved
networkctl reload
echo "installed. Check: networkctl   and   resolvectl status   (undo: sudo $0 --nm)"
