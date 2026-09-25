#!/usr/bin/env bash
# Install DNS config (needs sudo, once; again after editing network/*.conf).
#   sudo ./network/install-network.sh <adguard-profile-id>
#   sudo ./network/install-network.sh            reuse the ID already installed
# The ID is the part before .d.adguard-dns.com in the profile's DNS-over-TLS address.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
RES=/etc/systemd/resolved.conf.d/adguard.conf
NM=/etc/NetworkManager/conf.d/10-dotfiles-dns.conf

id="${1:-$(grep -oPm1 '#\K[0-9a-z]+(?=\.d\.adguard-dns\.com)' "$RES" 2>/dev/null || true)}"
[[ "$id" =~ ^[0-9a-z]+$ ]] || { echo "no AdGuard profile ID: pass it as the first argument" >&2; exit 1; }

install -Dm644 /dev/stdin "$RES" < <(sed "s/@ID@/$id/g" "$REPO/network/resolved.conf")
install -Dm644 "$REPO/network/NetworkManager.conf" "$NM"
ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl enable --now systemd-resolved avahi-daemon >/dev/null
systemctl restart systemd-resolved
systemctl reload NetworkManager
# drop the DHCP servers NM already pushed before dns=none took effect
for dev in $(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="ethernet"||$2=="wifi"{print $1}'); do
    resolvectl revert "$dev" 2>/dev/null || true
done
resolvectl flush-caches
echo "installed. Check: resolvectl status   (only the AdGuard servers, under Global)"
