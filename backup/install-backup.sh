#!/usr/bin/env bash
# Backup drive for restic. Run as root with the partition to use:
#   sudo ./backup/install-backup.sh LABEL=<label>      (or UUID=..., PARTUUID=...)
# 1. installs restic
# 2. adds an fstab automount at /mnt/backup: mounted on first access, unmounted after 10 idle minutes,
#    and a missing drive never holds up boot (nofail). NTFS mounts through ntfs3, owned by the desktop user.
# Then, as yourself: backup init   (creates the repository and its password file)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
SPEC="${1:-}"
[[ $SPEC == *=* ]] || { echo "usage: sudo $0 LABEL=<label>|UUID=<uuid>" >&2; exit 2; }
MNT=/mnt/backup
USER_NAME="${SUDO_USER:?run through sudo so the mount belongs to you}"
U=$(id -u "$USER_NAME"); G=$(id -g "$USER_NAME")

pacman -S --needed --noconfirm --asexplicit restic

dev=$(findfs "$SPEC") || { echo "no partition matches $SPEC" >&2; exit 1; }
fs=$(blkid -o value -s TYPE "$dev")
case "$fs" in
    ntfs)  type=ntfs3; opts="uid=$U,gid=$G,umask=077,windows_names" ;;
    ext4|btrfs|xfs) type=$fs; opts="defaults" ;;
    *) echo "$dev is $fs; expected ntfs, ext4, btrfs or xfs" >&2; exit 1 ;;
esac
line="$SPEC $MNT $type $opts,noauto,nofail,x-systemd.automount,x-systemd.idle-timeout=10min,x-systemd.device-timeout=5s 0 0"

mkdir -p "$MNT"
if grep -qE "[[:space:]]${MNT}[[:space:]]" /etc/fstab; then
    echo "fstab already has an entry for $MNT; leaving it:"; grep -E "[[:space:]]${MNT}[[:space:]]" /etc/fstab
else
    cp -a /etc/fstab /etc/fstab.bak-backup
    printf '\n# backup drive for restic (dotfiles backup/)\n%s\n' "$line" >> /etc/fstab
    echo "added to /etc/fstab (backup: /etc/fstab.bak-backup):"; echo "  $line"
fi
systemctl daemon-reload
systemctl restart "$(systemd-escape -p --suffix=automount "$MNT")"
ls "$MNT" >/dev/null && echo "$MNT mounts. Next, as $USER_NAME: backup init"
# ntfs3 refuses to mount a volume Windows left dirty (fast startup, hibernation): boot Windows and shut it down
# fully, or run: sudo ntfsfix -d $dev
