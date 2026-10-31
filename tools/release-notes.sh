#!/usr/bin/env bash
# Prints the release notes for a tag, for Google Play ("What's new"), TestFlight ("What to Test")
# and the GitHub Release. Used by .github/workflows/release.yml and codemagic.yaml.
#
#   tools/release-notes.sh <tag> <version> <build> [max characters]
#
# Notes come from, in order:
#   1. the tag's message, if it's an annotated tag (git tag -a m8.2 -m "Fixed ...")
#   2. otherwise the commit subjects since the previous m*/v* tag (checklist commits left out)
#   3. otherwise "Minor update for testing."
# Every release gets notes. Google Play allows 500 characters, so pass 500 there.
set -euo pipefail

tag="${1:?tag}"
version="${2:?version}"
build="${3:?build}"
max="${4:-4000}"

header="Thumb Party $version (build $build)"
body=""

if [ "$(git cat-file -t "refs/tags/$tag" 2>/dev/null || true)" = "tag" ]; then
  body="$(git tag -l --format='%(contents)' "$tag" | sed '/^-----BEGIN PGP SIGNATURE-----/,$d' | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d')"
fi

if [ -z "$body" ]; then
  previous="$(git describe --tags --abbrev=0 --match 'm*' --match 'v*' "$tag^" 2>/dev/null || true)"
  if [ -n "$previous" ]; then
    range="$previous..$tag"
  else
    range="$tag~10..$tag"
  fi
  body="$(git log --no-merges --format='%s' "$range" 2>/dev/null | grep -viE 'checklist' | head -n 8 | sed 's/^/- /' || true)"
fi

if [ -z "$body" ]; then
  body="Minor update for testing."
fi

notes="$header

$body"

# Too long: drop whole lines from the end, then say there's more.
if [ "${#notes}" -gt "$max" ]; then
  more="- and smaller fixes"
  while [ "$(( ${#notes} + ${#more} + 1 ))" -gt "$max" ] && [[ "$notes" == *$'\n'* ]]; do
    notes="${notes%$'\n'*}"
  done
  notes="$notes
$more"
  notes="${notes:0:$max}"
fi

printf '%s\n' "$notes"
