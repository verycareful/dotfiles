#!/usr/bin/env bash
# Weekly full scan of $HOME via clamd. Runs as the user (own files are readable,
# so no root needed). Reports and notifies; does not quarantine: the on-access
# tiers do that. Review hits in the log and decide.
set -uo pipefail
LOG_DIR="$HOME/.local/state/clamav"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/weekly-$(date +%F).log"
: > "$LOG"   # clamdscan --log appends; a second run on the same day would leave two summaries here

notify-send -a ClamAV -i security-medium "Weekly scan" "Scanning $HOME in the background…"
clamdscan --fdpass --multiscan --infected --log="$LOG" "$HOME"
rc=$?
# clamdscan exit: 0 clean, 1 infected, 2 = any error, which includes files that could not be scanned
# (sockets, pipes, files that vanished mid-scan). Exit 2 says nothing about infections, so read the
# summary instead. It is printed even when clamdscan gave up halfway (clamd restarted under it:
# "ERROR: Communication error"), and then counts only what was scanned. Per-file trouble is logged as
# WARNING or "ERROR: Can't access file"; any other ERROR line means the scan did not finish.
infected=$(grep -oE 'Infected files: [0-9]+' "$LOG" | grep -oE '[0-9]+$'); infected=${infected:-?}
errors=$(grep -oE 'Total errors: [0-9]+' "$LOG" | grep -oE '[0-9]+$'); errors=${errors:-0}
fatal=$(grep '^ERROR: ' "$LOG" | grep -v "^ERROR: Can't access file " | head -1); fatal=${fatal#ERROR: }; fatal=${fatal%.}
if [ "$infected" = "0" ] && [ -z "$fatal" ]; then
    notify-send -a ClamAV -i security-high "Weekly scan finished" "No threats found. ${errors} unscannable file(s) skipped."
elif [ "$infected" != "?" ] && [ "$infected" != "0" ]; then
    notify-send -a ClamAV -u critical -i security-low "Weekly scan: ${infected} infected file(s)" "${fatal:+Stopped early: ${fatal}. }See ${LOG}"
else
    notify-send -a ClamAV -u critical "Weekly scan did not complete (exit ${rc})" "${fatal:+${fatal}. }See ${LOG}"
fi
# keep 8 weeks of logs
ls -1t "$LOG_DIR"/weekly-*.log 2>/dev/null | tail -n +9 | xargs -r rm -f
exit 0
