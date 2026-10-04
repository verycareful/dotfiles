#!/usr/bin/env bash
# Decision tests for stage/usr/local/bin/clamav-watchdog. Needs no root and no clamd: pgrep, ps, socat and
# systemctl are fakes on PATH, clamd is a busy (`yes`) or idle (`sleep`) process, and the STATS replies
# are built below. Each case runs the watchdog twice, since the second strike is the one that restarts.
# The cases run in parallel because every run samples CPU for 5 s.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WATCHDOG="$HERE/../stage/usr/local/bin/clamav-watchdog"
T=$(mktemp -d)
yes >/dev/null & busy=$!
sleep 600 & idle=$!
trap 'kill "$busy" "$idle" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fx"

cat > "$T/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
case ${!#} in
    clamd)     echo "$FAKE_PID" ;;
    clamdscan) [[ -n $FAKE_SCAN_AGE ]] || exit 1; echo 4242 ;;
esac
EOF
cat > "$T/bin/ps" <<'EOF'
#!/usr/bin/env bash
printf '%7s\n' "$FAKE_SCAN_AGE"
EOF
cat > "$T/bin/socat" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null; [[ -s "$FX" ]] && { cat "$FX"; printf '\0'; }; exit 0
EOF
cat > "$T/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "RESTART $*"
EOF
chmod +x "$T/bin/"*

stats() { # fixture name, then one "CMD seconds [file]" per job
    local f="$T/fx/$1"; shift
    { printf 'POOLS: 1\n\nSTATE: VALID PRIMARY\nTHREADS: live %d  idle 0 max 40 idle-timeout 30\n' $(( $# + 1 ))
      printf 'QUEUE: 0 items\n\tSTATS 0.000001 \n'
      for j in "$@"; do printf '\t%s\n' "$j"; done
      printf '\nMEMSTATS: heap 1.000M\nEND'; } > "$f"
}
stats idle-only     "IDLE 12.100000" "IDLE 40.200000"
stats fildes-young  "FILDES 20.695833 fd[11]"
stats fildes-stuck  "FILDES 412.500000 fd[11]"
stats contscan-long "CONTSCAN 900.100000 /home/u"
scan=(); for i in $(seq 30); do scan+=("FILDES $(( i % 5 )).$(printf '%06d' "$i") fd[$(( i + 10 ))]"); done
stats weekly-scan "${scan[@]}"
: > "$T/fx/no-reply"

cases=(                       # clamd load, STATS reply, expected, age of a running clamdscan in s
    "busy idle-only restart"      # hot with nothing to scan
    "busy fildes-stuck restart"   # one file scanned far past MaxScanTime
    "busy no-reply restart"       # hot and not answering STATS
    "busy fildes-young leave"     # an on-access scan of a big file
    "busy contscan-long leave"    # a directory scan runs as long as its walk
    "busy weekly-scan leave"      # clamdscan --fdpass --multiscan: many short FILDES jobs
    "busy no-reply leave 600"     # the same scan with every thread taken, so STATS waits
    "busy no-reply restart 14400" # a clamdscan this old has outlived the weekly scan's timeout
    "busy idle-only restart 600"  # a running clamdscan does not excuse a clamd that answers idle
    "busy fildes-stuck restart 600" # nor one with a file stuck past MaxScanTime
    "idle idle-only leave"
    "idle fildes-stuck leave"
)

run() { # load fixture expected [clamdscan age]
    local pid=$busy d="$T/case-$1-$2-${4:-noscan}" out got=leave name="$1 $2${4:+ (clamdscan ${4}s)}"
    [[ $1 == idle ]] && pid=$idle
    mkdir -p "$d"; sed "s#^STATE=.*#STATE=$d/strikes#" "$WATCHDOG" > "$d/watchdog"
    out=$(for _ in 1 2; do FX="$T/fx/$2" FAKE_PID=$pid FAKE_SCAN_AGE=${4:-} PATH="$T/bin:$PATH" bash "$d/watchdog"; done)
    grep -q '^RESTART ' <<<"$out" && got=restart
    if [[ $got == "$3" ]]; then echo "PASS  $name: $got"
    else echo "FAIL  $name: expected $3, got $got"; sed 's/^/      /' <<<"$out"; fi
}

pids=()
for i in "${!cases[@]}"; do run ${cases[$i]} > "$T/result-$i" & pids+=($!); done
wait "${pids[@]}"
cat "$T"/result-*
fails=$(cat "$T"/result-* | grep -c '^FAIL')
echo "${#cases[@]} cases, $fails failed"
(( fails == 0 ))
