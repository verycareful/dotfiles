#!/usr/bin/env bash
# Desktop notifications for ClamAV on-access detections.
# Follows the journal of both clamonacc tiers (block + notify) and fires
# notify-send on FOUND / quarantine lines. No root, no sudo: the wheel group
# has read access to the system journal on Arch.
set -uo pipefail

journalctl -f -n0 -o cat -u 'clamav-clamonacc@*.service' | while IFS= read -r line; do
    case "$line" in
        *" FOUND")
            # /home/sricharan/Downloads/x.exe: Win.Trojan.Foo-123 FOUND
            file_path="${line%%: *}"
            signature="${line#*: }"; signature="${signature% FOUND}"
            notify-send -a ClamAV -u critical -i security-low \
                "Threat detected" "${signature}\n${file_path}"
            ;;
        *": moved to "*)
            # /home/sricharan/Downloads/x.exe: moved to '/var/lib/clamav/quarantine/x.exe'
            notify-send -a ClamAV -u normal -i security-medium \
                "File quarantined" "${line%%: *}"
            ;;
    esac
done
