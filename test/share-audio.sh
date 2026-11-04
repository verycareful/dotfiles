#!/usr/bin/env bash
# share-audio.sh: tests for the link decisions in scripts/.local/bin/share-audio.
#   test/share-audio.sh
# The fixture is a hand-built pw-dump: Spotify (no pid), Firefox (pid 500) and Discord's own playback (pid 600)
# are playing, and Discord has one capture stream per application, each with a stereo pair of links.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
command -v jq >/dev/null || { echo "jq is not installed" >&2; exit 1; }

readonly SCRIPT=scripts/.local/bin/share-audio
work=$(mktemp -d "${TMPDIR:-/var/tmp}/share-audio-test.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT

player() { # id serial name binary pid
    jq -n --argjson id "$1" --arg serial "$2" --arg name "$3" --arg bin "$4" --arg pid "$5" '
        {id: $id, type: "PipeWire:Interface:Node", info: {props: ({
            "media.class": "Stream/Output/Audio", "object.serial": ($serial | tonumber),
            "application.name": $name, "application.process.binary": $bin}
            + (if $pid == "" then {} else {"application.process.id": ($pid | tonumber)} end))}}'
}
capture() { # id target-serial
    jq -n --argjson id "$1" --argjson target "$2" '
        {id: $id, type: "PipeWire:Interface:Node", info: {props: {
            "media.class": "Stream/Input/Audio", "application.name": "discord_capture", "target.object": $target}}}'
}
link() { # id output-node input-node
    jq -n --argjson id "$1" --argjson out "$2" --argjson in "$3" '
        {id: $id, type: "PipeWire:Interface:Link", info: {"output-node-id": $out, "input-node-id": $in}}'
}

{
    player 10 100 Spotify spotify ""
    player 11 101 Firefox firefox 500
    player 12 102 discord Discord 600
    capture 20 100; capture 21 101; capture 22 102
    link 30 10 20; link 31 10 20
    link 32 11 21; link 33 11 21
    link 34 12 22; link 35 12 22
} | jq -s . > "$work/dump.json"

pass=0 fail=0
check() { # name allow-json expected-link-ids
    local name=$1 allow=$2 want=$3 got
    printf '%s' "$allow" > "$work/allow.json"
    got=$("$SCRIPT" decide "$work/allow.json" < "$work/dump.json" | sort -n | tr '\n' ' ')
    got=${got% }
    if [[ $got == "$want" ]]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL %s: want [%s] got [%s]\n' "$name" "$want" "$got"
    fi
}

check "all mode keeps every capture"                '{"mode":"all"}'                                              ""
check "unset mode keeps every capture"              '{}'                                                          ""
check "name match keeps Spotify (no pid)"           '{"mode":"window","pids":[],"names":["spotify"]}'             "32 33 34 35"
check "pid match keeps Firefox"                     '{"mode":"window","pids":[500],"names":[]}'                   "30 31 34 35"
check "binary name matches case-insensitively"      '{"mode":"window","pids":[],"names":["firefox"]}'             "30 31 34 35"
check "own Discord playback can be the shared app"  '{"mode":"window","pids":[600],"names":[]}'                   "30 31 32 33"
check "several apps can stay"                       '{"mode":"window","pids":[500],"names":["spotify"]}'          "34 35"
check "a window with no playing app keeps nothing"  '{"mode":"window","pids":[999],"names":["nothing"]}'         "30 31 32 33 34 35"
check "window mode with empty sets keeps nothing"   '{"mode":"window"}'                                           "30 31 32 33 34 35"

# a capture whose target is not an application stream (a device) is never touched
{
    jq '.[]' "$work/dump.json"
    capture 23 9999; link 36 40 23
} | jq -s . > "$work/dump.json.new" && mv "$work/dump.json.new" "$work/dump.json"
check "a capture of a device is left alone"         '{"mode":"window","pids":[],"names":["spotify"]}'             "32 33 34 35"

# resolve: the recorded choice and the window list become an ALLOW.json. pid 99999 is not a running process, so
# no children or /proc names are added and the result depends on the fixture alone.
printf '%s' '100[HC>]Spotify[HT>]Spotify Premium[HE>]255[HA>]101[HC>]kitty[HT>]a title[HE>]4096[HA>]' > "$work/windows"
printf '[{"address":"0xff","pid":99999,"class":"Spotify","initialClass":"Spotify"}]' > "$work/clients.json"

expect() { # name want-json got-json
    if [[ $(jq -cS . <<< "$3") == "$(jq -cS . <<< "$2")" ]]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL %s: want %s got %s\n' "$1" "$2" "$3"
    fi
}
resolve() { # selection-line
    printf '%s\n' "$1" > "$work/selection"
    SHARE_AUDIO_OVERRIDES="$work/overrides" "$SCRIPT" resolve "$work/selection" "$work/windows" "$work/clients.json"
}

expect "window selection gives its pid and class"   '{"mode":"window","pids":[99999],"names":["spotify"]}'  "$(resolve '[SELECTION]/window:100')"
expect "flags before the slash are ignored"         '{"mode":"window","pids":[99999],"names":["spotify"]}'  "$(resolve '[SELECTION]r/window:100')"
expect "a window missing from hyprctl keeps its class" '{"mode":"window","pids":[],"names":["kitty"]}'      "$(resolve '[SELECTION]/window:101')"
expect "a screen share allows everything"           '{"mode":"all"}'                                        "$(resolve '[SELECTION]/screen:DP-3')"
expect "a region share allows everything"           '{"mode":"all"}'                                        "$(resolve '[SELECTION]/region:DP-3@0,0,10,10')"
expect "an unknown window handle changes nothing"   '{"mode":"none"}'                                       "$(resolve '[SELECTION]/window:999')"
expect "an unreadable selection changes nothing"    '{"mode":"none"}'                                       "$(resolve 'garbage')"
rm -f "$work/selection"
expect "no recorded selection changes nothing"      '{"mode":"none"}' \
    "$(SHARE_AUDIO_OVERRIDES="$work/overrides" "$SCRIPT" resolve "$work/selection" "$work/windows" "$work/clients.json")"

printf '# a comment\nspotify = Spotify-Helper\n' > "$work/overrides"
expect "an override adds a stream name"             '{"mode":"window","pids":[99999],"names":["spotify","spotify-helper"]}' "$(resolve '[SELECTION]/window:100')"

printf '%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
