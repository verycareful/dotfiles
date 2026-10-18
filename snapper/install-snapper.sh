#!/usr/bin/env bash
# Btrfs snapshots of / with snapper. Run as root:  sudo ./snapper/install-snapper.sh
# 1. snap-pac takes a pre/post snapshot pair around every pacman transaction
# 2. the timeline timer keeps hourly/daily/weekly snapshots, the cleanup timer prunes them (limits below)
# 3. grub-btrfsd adds a "snapshots" submenu to GRUB, so a broken update can be booted around
# 4. the wheel group may list and create snapshots without root (the panel's Safeguards card and `snap`)
# /home is not snapshotted: game libraries churn hundreds of GB there. restic covers it (backup/).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
[[ $(findmnt -no FSTYPE /) == btrfs ]] || { echo "/ is not btrfs; snapper needs it" >&2; exit 1; }

step "Installing snapper, snap-pac, grub-btrfs"
pacman -S --needed --noconfirm --asexplicit snapper snap-pac grub-btrfs inotify-tools

step "Root config"
if ! snapper -c root get-config >/dev/null 2>&1; then
    # create-config makes its own /.snapshots subvolume; an existing plain directory there blocks it
    [[ -d /.snapshots ]] && ! btrfs subvolume show /.snapshots >/dev/null 2>&1 && rmdir /.snapshots
    snapper -c root create-config /
fi
snapper -c root set-config \
    ALLOW_GROUPS=wheel SYNC_ACL=yes \
    TIMELINE_CREATE=yes TIMELINE_CLEANUP=yes TIMELINE_MIN_AGE=1800 \
    TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=4 \
    TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
    NUMBER_CLEANUP=yes NUMBER_LIMIT=50 NUMBER_LIMIT_IMPORTANT=15 \
    SPACE_LIMIT=0.5 FREE_LIMIT=0.2

step "Timers and the GRUB snapshot menu"
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service
grub-mkconfig -o /boot/grub/grub.cfg

step "Done"
snapper -c root list | tail -n 5
