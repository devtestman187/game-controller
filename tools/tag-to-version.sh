#!/usr/bin/env bash
# Prints the app version for a release tag, so both apps take their version from the tag:
# m16.4 -> 0.16.4 (milestone 16, release 4), m16 -> 0.16.0, v1.0 -> 1.0.0, v2 -> 2.0.0.
# Any other tag, or a wrong number of arguments, exits 2 with a message on stderr.
#
#   bash tools/tag-to-version.sh m16.4     # prints 0.16.4
#
# tools/release.sh uses it; tools/tests/tag-to-version-test.sh checks it.
set -u

die() { echo "tag-to-version: $*" >&2; exit 2; }

[ $# -eq 1 ] || die "give exactly one tag (for example m16.4)"
tag="$1"
if [[ "$tag" =~ ^m([0-9]+)(\.([0-9]+))?$ ]]; then
  echo "0.${BASH_REMATCH[1]}.${BASH_REMATCH[3]:-0}"
elif [[ "$tag" =~ ^v([0-9]+)(\.([0-9]+))?$ ]]; then
  echo "${BASH_REMATCH[1]}.${BASH_REMATCH[3]:-0}.0"
else
  die "tag '$tag' has no app version (m16.4 -> 0.16.4, v1.0 -> 1.0.0)"
fi
