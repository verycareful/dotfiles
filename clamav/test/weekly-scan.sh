#!/usr/bin/env bash
# Verdict tests for scripts/.local/bin/clamav-weekly-scan.sh. clamdscan is a fake that appends a canned
# log and exits with a chosen code, notify-send prints the title and body it was given, and HOME is a
# temp dir. Checks which notification each clamdscan outcome produces, and that a second run on the
# same day leaves one summary in the log. The scan runs one clamdscan per top-level entry of HOME, so cases
# can add entries, make one entry fail every time, or give a second attempt another result (the retry).
# systemctl is a fake too (a unit is active while a file named after it exists in $SD), for the pause of
# the on-access notify tier around the scan. $SD sits beside the fake HOME, so it is not scanned.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SCAN="$HERE/../../scripts/.local/bin/clamav-weekly-scan.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fx"

cat > "$T/bin/clamdscan" <<'EOF'
#!/usr/bin/env bash
for a; do [[ $a == --log=* ]] && log=${a#--log=}; done
path=${!#}; fx=$FX; rc=$RC
echo "$path" >> "$SD/scanned"
seen="$SD/seen${path//\//_}"; [[ -e $seen && -n ${FX_SECOND:-} ]] && fx=$FX_SECOND; touch "$seen"
[[ -n ${FAIL_ENTRY:-} && $path == */"$FAIL_ENTRY" ]] && { fx=$FAIL_FX; rc=2; }   # this entry fails every time
[[ -e $SD/clamav-clamonacc@notify.service ]] && echo on > "$SD/tier-during-scan" || echo off > "$SD/tier-during-scan"
[[ -n ${MASTER_OFF:-} ]] && rm -f "$SD/clamav-daemon.socket"      # the panel switched ClamAV off mid-scan
[[ -n ${HANG:-} ]] && { touch "$SD/scanning"; sleep 30; }
cat "$fx" >> "$log"; exit "$rc"
EOF
cat > "$T/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
args=(); for a; do [[ $a == -* ]] || args+=("$a"); done
echo "${args[*]}" >> "$SD/calls"
case ${args[0]} in
    is-active) [[ -e $SD/${args[1]} ]] ;;
    start)     [[ -z ${DENY:-} ]] || exit 1; touch "$SD/${args[1]}" ;;
    stop)      [[ -z ${DENY:-} ]] || exit 1; rm -f "$SD/${args[1]}" ;;
esac
EOF
cat > "$T/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
args=(); skip=0
for a; do
    if (( skip )); then skip=0; continue; fi
    case $a in -a|-i|-u) skip=1 ;; -*) ;; *) args+=("$a") ;; esac
done
[[ ${args[0]} == "Weekly scan" ]] || printf '%s | %s\n' "${args[0]}" "${args[1]:-}"
EOF
chmod +x "$T/bin/"*

summary() { printf '\n----------- SCAN SUMMARY -----------\nInfected files: %s\n%sTime: 5.000 sec (0 m 5 s)\n' "$1" "${2:+Total errors: $2
}"; }
rule='--------------------------------------'
{ echo "$rule"; summary 0; }                                                     > "$T/fx/clean"
{ echo "$rule"; echo "WARNING: /home/u/.steam/steam.pipe: Not supported file type"
  echo "WARNING: /home/u/agent.sock: Not supported file type"; summary 0 2; }    > "$T/fx/unscannable"
{ echo "$rule"; echo "ERROR: Can't access file /home/u/root-owned"; summary 0 1; } > "$T/fx/cant-access"
{ echo "$rule"; echo "/home/u/Downloads/x.exe: Win.Test.EICAR_HDB-1 FOUND"; summary 1; } > "$T/fx/infected"
{ echo "$rule"; echo "ERROR: Communication error"; summary 0; }                  > "$T/fx/aborted"
{ echo "$rule"; echo "/home/u/Downloads/x.exe: Win.Test.EICAR_HDB-1 FOUND"
  echo "ERROR: Communication error"; summary 1; }                                > "$T/fx/infected-aborted"
{ echo "$rule"; echo "ERROR: Clamd closed the connection before scanning all files."; summary 0; } > "$T/fx/closed"
{ echo "$rule"; echo "ERROR: Could not connect to clamd on LocalSocket /run/clamav/clamd.ctl: Connection refused"; } > "$T/fx/no-clamd"
echo "$rule"                                                                     > "$T/fx/timed-out"

F="$T/fx"
cases=(   # fixture | exit | expected title | expected in body | log already there today | env | extra entries in HOME | expected in log
    "clean|0|Weekly scan finished|No threats found. 0 unscannable||||Scanned ~/.local in"
    "unscannable|2|Weekly scan finished|2 unscannable file(s) skipped||||"
    "cant-access|2|Weekly scan finished|1 unscannable file(s) skipped||||"
    "infected|1|Weekly scan: 1 infected file(s)|See ||||x.exe: Win.Test.EICAR_HDB-1 FOUND"
    "aborted|2|Weekly scan did not complete (exit 2)|~/.local: Communication error. See ||||NOTE: ~/.local: session stopped"
    "infected-aborted|1|Weekly scan: 1 infected file(s)|Stopped early: ~/.local: Communication error. See ||||"
    "closed|2|Weekly scan did not complete (exit 2)|before scanning all files. See ||||"
    "no-clamd|2|Weekly scan did not complete (exit 2)|Connection refused. See ||||"
    "timed-out|124|Weekly scan did not complete (exit 124)|Timed out after 4 h, in ~/.local. See ||||"
    "clean|0|Weekly scan finished|No threats found.|aborted|||"
    # the retry: a session that stops early is run once more, and only the second result counts
    "aborted|2|Weekly scan finished|No threats found.||FX_SECOND=$F/clean||NOTE: ~/.local: session stopped"
    # a detection made by the attempt that stopped early is kept, and found again it counts once
    "infected-aborted|1|Weekly scan: 1 infected file(s)|See ||FX_SECOND=$F/infected||x.exe: Win.Test.EICAR_HDB-1 FOUND"
    # every top-level entry has its own session, and the summary adds them up
    "unscannable|2|Weekly scan finished|6 unscannable file(s) skipped|||Docs Music|Scanned ~/Music in"
    # an entry that fails twice is named, and the entries after it are still scanned
    "clean|0|Weekly scan did not complete (exit 2)|~/Docs: Communication error. See ||FAIL_ENTRY=Docs FAIL_FX=$F/aborted|Docs Music|Scanned ~/Music in"
)

fails=0; n=0
for c in "${cases[@]}"; do
    IFS='|' read -r fx rc title body pre env extra inlog <<<"$c"
    n=$(( n + 1 )); home="$T/home-$n"; log="$home/.local/state/clamav/weekly-$(date +%F).log"
    mkdir -p "${log%/*}" "$home.sd"; [[ -n $pre ]] && cp "$T/fx/$pre" "$log"
    for e in $extra; do mkdir -p "$home/$e"; done
    out=$(env HOME="$home" SD="$home.sd" XDG_RUNTIME_DIR="$home.sd" FX="$T/fx/$fx" RC=$rc PATH="$T/bin:$PATH" $env \
          bash "$SCAN" 2>/dev/null | grep -v '^== ')
    got_title=${out%% | *}; got_body=${out#* | }
    summaries=$(grep -c 'SCAN SUMMARY' "$log"); found=$(grep -c ' FOUND$' "$log")
    name="$fx (exit $rc)${pre:+ after an earlier $pre run}${env:+, ${env%%=*}}${extra:+, entries $extra}"
    if [[ $got_title == "$title" && $got_body == *"$body"* && $summaries -le 1 && $found -le 1 \
          && ( -z $inlog || $(cat "$log") == *"$inlog"* ) ]]; then
        echo "PASS  $name: $got_title"
    else
        echo "FAIL  $name"; echo "      got:  $out"; echo "      want: $title | ...$body..."
        echo "      summaries in log: $summaries, FOUND lines: $found${inlog:+, want in log: $inlog}"
        sed 's/^/      log: /' "$log"; fails=$(( fails + 1 ))
    fi
done

# Pause of the notify tier. Each case starts with the units named in $2 active, runs the scan (or kills it,
# or runs only the ExecStopPost step), then checks the tier's state during clamdscan and afterwards.
tier=clamav-clamonacc@notify.service
pause_case() { # name | units active at start | how | env | tier during scan | tier after | must appear in calls or stderr
    local name=$1 start=$2 how=$3 env=$4 want_during=$5 want_after=$6 want_text=$7
    local home="$T/pause-${name// /-}" sd during after err pid
    sd="$home.sd"; mkdir -p "$home/.local/state/clamav" "$sd"
    for u in $start; do touch "$sd/$u"; done
    local run=(env HOME="$home" SD="$sd" XDG_RUNTIME_DIR="$sd" FX="$T/fx/clean" RC=0 PATH="$T/bin:$PATH" $env)
    case $how in
        scan)   "${run[@]}" bash "$SCAN" > /dev/null 2> "$sd/stderr" ;;
        term|kill)
            setsid "${run[@]}" HANG=1 bash "$SCAN" > /dev/null 2> "$sd/stderr" & pid=$!
            for _ in $(seq 50); do [[ -e $sd/scanning ]] && break; sleep 0.1; done
            kill "-${how^^}" -- "-$pid"; wait "$pid" 2>/dev/null
            [[ $how == kill ]] && "${run[@]}" bash "$SCAN" --resume-notify-tier ;;   # what ExecStopPost runs
        resume) "${run[@]}" bash "$SCAN" --resume-notify-tier ;;
    esac
    during=$(cat "$sd/tier-during-scan" 2>/dev/null || echo -); after=off; [[ -e $sd/$tier ]] && after=on
    err=$(cat "$sd/calls" "$sd/stderr" 2>/dev/null)
    if [[ $during == "$want_during" && $after == "$want_after" && ! -e $sd/clamav-weekly-scan.notify-paused \
          && ( -z $want_text || $err == *"$want_text"* ) ]]; then
        echo "PASS  pause: $name: during $during, after $after"
    else
        echo "FAIL  pause: $name: during $during (want $want_during), after $after (want $want_after)"
        [[ -n $want_text ]] && echo "      want in calls/stderr: $want_text"
        sed 's/^/      /' <<<"$err"; fails=$(( fails + 1 ))
    fi
}
sock=clamav-daemon.socket
pause_case "tier on"                    "$sock $tier" scan   ""            off on  "stop $tier"
pause_case "tier already off"           "$sock"       scan   ""            off off ""
pause_case "polkit refuses"             "$sock $tier" scan   "DENY=1"      on  on  "could not pause"
pause_case "ClamAV switched off mid-scan" "$sock $tier" scan "MASTER_OFF=1" off off ""
pause_case "scan stopped (SIGTERM)"     "$sock $tier" term   ""            off on  ""
pause_case "scan killed (SIGKILL)"      "$sock $tier" kill   ""            off on  ""
pause_case "ExecStopPost, no pause held" "$sock"      resume ""            -   off ""
echo "$(( ${#cases[@]} + 7 )) cases, $fails failed"
(( fails == 0 ))
