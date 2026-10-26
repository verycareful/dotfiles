#!/usr/bin/env bash
# lint.sh: every check CI runs (.github/workflows/ci.yml), runnable locally before a push.
#   ShellCheck (warning level) on every tracked shell script, luac -p on the Hyprland Lua config,
#   the perms and theme unit tests, theme check on every theme, and secrets.sh. A missing tool is reported and skipped locally, fatal in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
need() {
    command -v "$1" >/dev/null && return 0
    echo "skip: $1 not installed"
    [[ -n ${CI:-} ]] && fail=1
    return 1
}
step() { printf '\n== %s\n' "$*"; }

step shellcheck
if need shellcheck; then
    mapfile -t sh < <(git ls-files | while read -r f; do [[ -f $f ]] && head -1 "$f" | grep -qE '^#!.*\b(ba)?sh\b' && echo "$f"; done)
    shellcheck -S warning "${sh[@]}" || fail=1
    echo "${#sh[@]} scripts"
fi

step "luac -p (Hyprland Lua)"
luac=$(command -v luac5.4 || command -v luac || true)
if [[ -n $luac ]]; then
    git ls-files '*.lua' | xargs -r "$luac" -p || fail=1
else
    need luac
fi

step "perms tests"
need python3 && { python3 -B -m unittest discover -s perms/test || fail=1; }

step "theme tests"
need python3 && { python3 -B -m unittest discover -s themes/test || fail=1; }

step "theme check"
need python3 && { python3 -B themes/render.py check || fail=1; }

step secrets
test/secrets.sh || fail=1

exit $fail
