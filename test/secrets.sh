#!/usr/bin/env bash
# secrets.sh: refuse content that must never reach the public repo.
#   test/secrets.sh            scan every tracked file
#   test/secrets.sh --staged   scan only what is staged (the pre-commit hook)
# Patterns: AdGuard DNS profile IDs (<8 hex>.d.adguard-dns.com, they identify the account) and private keys.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
PATTERN='[0-9a-f]{8}\.d\.adguard-dns\.com|-----BEGIN [A-Z ]*PRIVATE KEY-----'

if [[ ${1:-} == --staged ]]; then
    hits=$(git diff --cached -U0 --no-color | grep -E '^\+' | grep -vE '^\+\+\+ ' | grep -nE "$PATTERN")
else
    hits=$(git grep -nIE "$PATTERN")
fi
if [[ -n $hits ]]; then
    echo "secrets.sh: refusing, this must not be published:" >&2
    echo "$hits" >&2
    exit 1
fi
