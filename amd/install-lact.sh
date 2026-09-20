#!/usr/bin/env bash
# Set up LACT (AMD GPU control: clocks, power limit, fan curve) — needs sudo.
#   sudo ./amd/install-lact.sh
# 1. installs lact and enables its daemon (the GUI talks to lactd; settings persist in /etc/lact/config.yaml)
# 2. adds amdgpu.ppfeaturemask=0xffffffff to the kernel command line: without it the driver's
#    overdrive interface (/sys/class/drm/card*/device/pp_od_clk_voltage) does not exist and
#    every GPU knob is read-only. Takes effect after a reboot.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
MASK='amdgpu.ppfeaturemask=0xffffffff'

pacman -S --needed --noconfirm --asexplicit lact
systemctl enable --now lactd.service

GRUB=/etc/default/grub
if grep -q "$MASK" "$GRUB"; then
    echo "kernel parameter already present"
else
    cp -a "$GRUB" "$GRUB.bak-lact"
    sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT='[^']*\)'/\1 $MASK'/" "$GRUB"
    grep -q "$MASK" "$GRUB" || { echo "could not edit GRUB_CMDLINE_LINUX_DEFAULT in $GRUB (quoting?) — add '$MASK' by hand" >&2; exit 1; }
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "added $MASK to $GRUB (backup: $GRUB.bak-lact) and regenerated grub.cfg"
fi
grep -q "$MASK" /proc/cmdline && echo "overdrive already active" || echo "reboot to unlock overdrive, then open LACT (SUPER+Space → LACT, or click the GPU readout on the bar)"
