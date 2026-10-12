#!/usr/bin/env bash
# Weekly full scan of $HOME via clamd, one clamdscan session per top-level entry. Runs as the user (own
# files are readable, so no root needed). Reports and notifies; does not quarantine: the on-access
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
: > "$LOG"   # a second run on the same day replaces the first one's report
WORK=$(mktemp -d)
finish() { rm -rf "$WORK"; resume_notify_tier; }

trap finish EXIT
trap 'exit 143' TERM; trap 'exit 129' HUP; trap 'exit 130' INT   # so the EXIT trap runs on these too
if systemctl is-active -q "$NOTIFY_TIER"; then
    : > "$PAUSED"   # before the stop, so a kill between the two still leaves the tier to be restarted
    systemctl --no-ask-password stop "$NOTIFY_TIER" || { rm -f "$PAUSED"; echo "could not pause $NOTIFY_TIER, scanning with it running" >&2; }
fi

notify-send -a ClamAV -i security-medium "Weekly scan" "Scanning $HOME in the background…"

# One session over all of ~ has died at about 42 min with "Communication error" (clamd closed it; see
# local/notes/clamd-spin.md), taking the rest of the walk with it. So each top-level entry gets its own
# session, and a session that stops early gets one retry. Each session's report goes to $WORK/entry.log
# first; the weekly log gets one line per entry, the per-file lines and one summary over all of them.
# clamdscan exit: 0 clean, 1 infected, 2 = any error, which includes files that could not be scanned
# (sockets, pipes, files that vanished mid-scan). Exit 2 says nothing about infections, so the report is
# read instead. Per-file trouble is logged as WARNING, "ERROR: Can't access file" or "<file>: <why> ERROR";
# any other ERROR line means the session stopped before the end of its walk.
started=$(date '+%Y:%m:%d %H:%M:%S')
rc=0; fatal_rc=0; errors=0; timed_out=""
: > "$WORK/found"
mapfile -d '' entries < <(find "$HOME" -mindepth 1 -maxdepth 1 -printf '%f\0' | sort -z)
for entry in "${entries[@]}"; do
    for attempt in 1 2; do
        left=$(( MAXSCAN - SECONDS ))
        (( left > 0 )) || { timed_out=1; echo "ERROR: Timed out after $(( MAXSCAN / 3600 )) h, before ~/$entry" >> "$LOG"; break; }
        : > "$WORK/entry.log"; t0=$SECONDS
        echo "== ~/$entry"
        timeout --kill-after=60 "$left" clamdscan --fdpass --multiscan --infected --log="$WORK/entry.log" "$HOME/$entry"
        erc=$?
        # 124 is the SIGTERM at the deadline, 137 its SIGKILL a minute later; 137 before it is some other kill
        (( erc == 124 || (erc == 137 && SECONDS >= MAXSCAN) )) && timed_out=1
        grep ' FOUND$' "$WORK/entry.log" >> "$WORK/found"   # from every attempt: a detection is never dropped
        efatal=$(grep '^ERROR: ' "$WORK/entry.log" | grep -v "^ERROR: Can't access file " | head -1)
        efatal=${efatal#ERROR: }; efatal=${efatal%.}
        if [[ -n $efatal && $attempt == 1 && -z $timed_out ]]; then
            echo "NOTE: ~/$entry: session stopped after $(( SECONDS - t0 )) s ($efatal), retrying" >> "$LOG"
            continue
        fi
        grep -E "^WARNING|^ERROR: Can't access file | ERROR$" "$WORK/entry.log" >> "$LOG"
        e=$(grep -oE 'Total errors: [0-9]+' "$WORK/entry.log" | grep -oE '[0-9]+$'); errors=$(( errors + ${e:-0} ))
        (( erc )) && rc=$erc
        if [[ -n $timed_out ]]; then
            echo "ERROR: Timed out after $(( MAXSCAN / 3600 )) h, in ~/$entry" >> "$LOG"
        elif [[ -n $efatal ]]; then
            echo "ERROR: ~/$entry: $efatal" >> "$LOG"; (( fatal_rc )) || fatal_rc=$erc
        else
            echo "Scanned ~/$entry in $(( SECONDS - t0 )) s" >> "$LOG"
        fi
        break
    done
    [[ -z $timed_out ]] || break
done
(( fatal_rc )) && rc=$fatal_rc
infected=$(sort -u "$WORK/found" | tee -a "$LOG" | wc -l)   # by path: a file found in both attempts counts once
{
    echo; echo "----------- SCAN SUMMARY -----------"
    echo "Infected files: $infected"
    (( errors )) && echo "Total errors: $errors"
    echo "Time: $SECONDS sec ($(( SECONDS / 60 )) m $(( SECONDS % 60 )) s)"
    echo "Start Date: $started"
    echo "End Date:   $(date '+%Y:%m:%d %H:%M:%S')"
} >> "$LOG"
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
