#!/usr/bin/env bash
# Verdict tests for scripts/.local/bin/clamav-weekly-scan.sh. clamdscan is a fake that appends a canned
# log and exits with a chosen code, notify-send prints the title and body it was given, and HOME is a
# temp dir. Checks which notification each clamdscan outcome produces, and that a second run on the
# same day leaves one summary in the log.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SCAN="$HERE/../../scripts/.local/bin/clamav-weekly-scan.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fx"

cat > "$T/bin/clamdscan" <<'EOF'
#!/usr/bin/env bash
for a; do [[ $a == --log=* ]] && log=${a#--log=}; done; cat "$FX" >> "$log"; exit "$RC"
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

cases=(   # fixture | exit | expected title | expected in body | log already there today
    "clean|0|Weekly scan finished|No threats found. 0 unscannable||"
    "unscannable|2|Weekly scan finished|2 unscannable file(s) skipped||"
    "cant-access|2|Weekly scan finished|1 unscannable file(s) skipped||"
    "infected|1|Weekly scan: 1 infected file(s)|See ||"
    "aborted|2|Weekly scan did not complete (exit 2)|Communication error. See ||"
    "infected-aborted|1|Weekly scan: 1 infected file(s)|Stopped early: Communication error. See ||"
    "closed|2|Weekly scan did not complete (exit 2)|before scanning all files. See ||"
    "no-clamd|2|Weekly scan did not complete (exit 2)|Connection refused. See ||"
    "clean|0|Weekly scan finished|No threats found.|aborted"
)

fails=0
for c in "${cases[@]}"; do
    IFS='|' read -r fx rc title body pre <<<"$c"
    home="$T/home-$fx-${pre:-fresh}"; log="$home/.local/state/clamav/weekly-$(date +%F).log"
    mkdir -p "${log%/*}"; [[ -n $pre ]] && cp "$T/fx/$pre" "$log"
    out=$(HOME="$home" FX="$T/fx/$fx" RC=$rc PATH="$T/bin:$PATH" bash "$SCAN")
    got_title=${out%% | *}; got_body=${out#* | }
    summaries=$(grep -c 'SCAN SUMMARY' "$log")
    name="$fx (exit $rc)${pre:+ after an earlier $pre run}"
    if [[ $got_title == "$title" && $got_body == *"$body"* && $summaries -le 1 ]]; then
        echo "PASS  $name: $got_title"
    else
        echo "FAIL  $name"; echo "      got:  $out"; echo "      want: $title | ...$body..."
        echo "      summaries in log: $summaries"; fails=$(( fails + 1 ))
    fi
done
echo "${#cases[@]} cases, $fails failed"
(( fails == 0 ))
