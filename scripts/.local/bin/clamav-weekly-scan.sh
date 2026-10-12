#!/usr/bin/env bash
# Weekly full scan of $HOME via clamd. Runs as the user (own files are readable,
# so no root needed). Reports and notifies; does not quarantine: the on-access
# tiers do that. Review hits in the log and decide.
set -uo pipefail
# clamav-watchdog does not count clamd's silence against it while a clamdscan younger than this runs
# (the scan holds every clamd thread), so the scan must not outlive it. Keep the two in step.
MAXSCAN=14400 # s

# The notify tier scans every file opened by anyone but clamav, this scan included, so it would queue a
# second clamd job for each file the scan reads. With clamd's threads already full, those jobs pile up and
# starve the scan's session. The tier is paused for the scan, which covers everything it would have seen.
# 50-dotfiles-clamav.rules lets wheel start and stop this one unit without a password.
NOTIFY_TIER=clamav-clamonacc@notify.service
PAUSED="${XDG_RUNTIME_DIR:-/tmp}/clamav-weekly-scan.notify-paused"   # exists only while this scan holds the tier
resume_notify_tier() {
    [[ -e $PAUSED ]] || return 0
    rm -f "$PAUSED"
    # the panel's master switch stops the socket with everything else; the tier stays off with ClamAV
    systemctl is-active -q clamav-daemon.socket && systemctl --no-ask-password start "$NOTIFY_TIER"
}
# clamav-weekly-scan.service runs this as ExecStopPost, for a scan killed before its EXIT trap could run
if [[ ${1:-} == --resume-notify-tier ]]; then resume_notify_tier; exit 0; fi

LOG_DIR="$HOME/.local/state/clamav"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/weekly-$(date +%F).log"
: > "$LOG"   # clamdscan --log appends; a second run on the same day would leave two summaries here

trap resume_notify_tier EXIT
trap 'exit 143' TERM; trap 'exit 129' HUP; trap 'exit 130' INT   # so the EXIT trap runs on these too
if systemctl is-active -q "$NOTIFY_TIER"; then
    : > "$PAUSED"   # before the stop, so a kill between the two still leaves the tier to be restarted
    systemctl --no-ask-password stop "$NOTIFY_TIER" || { rm -f "$PAUSED"; echo "could not pause $NOTIFY_TIER, scanning with it running" >&2; }
fi

notify-send -a ClamAV -i security-medium "Weekly scan" "Scanning $HOME in the background…"
timeout --kill-after=60 "$MAXSCAN" clamdscan --fdpass --multiscan --infected --log="$LOG" "$HOME"
rc=$?
# a clamdscan stopped by timeout writes no ERROR line of its own, and the verdict below needs one. 124 is
# SIGTERM, 137 the SIGKILL a minute later; 137 before the deadline is some other kill and stays unexplained.
(( rc == 124 || (rc == 137 && SECONDS >= MAXSCAN) )) && echo "ERROR: Timed out after $(( MAXSCAN / 3600 )) h" >> "$LOG"
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
