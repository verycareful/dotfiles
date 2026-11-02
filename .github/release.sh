#!/usr/bin/env bash
# release.sh: create the GitHub Release for a version tag. Run by CI on a tag push, after lint passes.
#   .github/release.sh LABEL           check the tag, then create the release (needs GH_TOKEN)
#   .github/release.sh LABEL --dry-run check the tag and print the title, notes and the bootstrap.sh tag line
# The title is the annotated tag's subject (`git tag -a 1.0.8.0 -m '1.0.8.0: subject'`), the notes are the
# version's CHANGELOG.md entry, and bootstrap.sh is attached with RELEASE_TAG set to the tag. A release that
# already exists is left alone, so re-running a job is safe.
set -euo pipefail
label="${1:?usage: release.sh LABEL [--dry-run]}"
dry="${2:-}"
die() { echo "release: $*" >&2; exit 1; }

[[ "$label" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$label is not a four-part version label"
[[ "$(git cat-file -t "refs/tags/$label" 2>/dev/null)" == tag ]] || die "$label is not an annotated tag"
version=$(git show "$label:VERSION" | tr -d '[:space:]')
[[ "$version" == "$label" ]] || die "VERSION at $label says $version"

title=$(git for-each-ref "refs/tags/$label" --format='%(contents:subject)')
[[ "$title" == "$label: "* ]] || die "tag message '$title' does not start with '$label: '"

# the entry runs from its own heading to the next version heading
notes=$(git show "$label:CHANGELOG.md" | awk -v h="## [$label]" '
    index($0, h) == 1 { on = 1; next }
    on && /^## \[/    { exit }
    on                { print }')
[[ -n "${notes//[[:space:]]/}" ]] || die "CHANGELOG.md at $label has no entry for $label"

# bootstrap.sh as it is at the tag, with RELEASE_TAG set so the copy installs this release
bootstrap=$(git show "$label:bootstrap.sh" 2>/dev/null) || die "$label has no bootstrap.sh"
grep -qx 'readonly RELEASE_TAG=""' <<<"$bootstrap" || die "bootstrap.sh at $label has no empty RELEASE_TAG line"
bootstrap=$(sed "s/^readonly RELEASE_TAG=\"\"\$/readonly RELEASE_TAG=\"$label\"/" <<<"$bootstrap")

if [[ "$dry" == --dry-run ]]; then
    printf 'title: %s\n\n%s\n\nasset: bootstrap.sh, %s\n' "$title" "$notes" "$(grep '^readonly RELEASE_TAG=' <<<"$bootstrap")"
    exit 0
fi
if gh release view "$label" >/dev/null 2>&1; then
    echo "release: $label already has a release, left as it is"
    exit 0
fi
assets="${RUNNER_TEMP:?release assets are written under RUNNER_TEMP, set in CI}/release-assets"
mkdir -p "$assets"
printf '%s\n' "$bootstrap" > "$assets/bootstrap.sh"
gh release create "$label" --verify-tag --title "$title" --notes "$notes" "$assets/bootstrap.sh"
