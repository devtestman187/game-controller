#!/usr/bin/env bash
# Tags a release with tester notes, pushes it, waits for every build and
# upload, and prints one summary. Documented in docs/dev-tools.md and
# docs/release.md.
#
#   tools/release.sh m10.3 "What changed, for testers"     # asks before tagging
#   tools/release.sh m10.3 "..." --yes                     # no question (scripts, agents)
#   tools/release.sh m10.3 "..." --no-wait                 # tag and push only
#   tools/release.sh --status m10.2                        # check an existing release
#
# What it checks first: the tag is new and looks like m10, m10.1 or v1.0;
# the notes aren't empty and fit Google Play (500 characters with the
# header); tracked files have no uncommitted changes; this commit is the
# tip of origin/main; both apps have the same version.
# Then: annotated tag on HEAD, push, wait for the GitHub "Release" run
# (Android bundles to Play, Windows zip to a GitHub Release) and the
# Codemagic TestFlight check, and print what each did.
# Exit code: 0 all good, 1 a build or upload failed or timed out, 2 a check
# before tagging failed (nothing was tagged). Needs git, gh (signed in) and bash.
set -u

cd "$(dirname "$0")/.." || exit 2

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "release: $*" >&2; exit 2; }

tag=""
notes=""
yes=0
wait=1
status_only=0
args=()
for arg in "$@"; do
  case "$arg" in
    -y | --yes) yes=1 ;;
    --no-wait) wait=0 ;;
    --status) status_only=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) die "unknown option $arg (try --help)" ;;
    *) args+=("$arg") ;;
  esac
done
tag="${args[0]:-}"
notes="${args[1]:-}"
[ -n "$tag" ] || { usage; exit 2; }

for tool in git gh; do
  command -v "$tool" > /dev/null 2>&1 || die "$tool isn't on the PATH (see docs/dev-tools.md)"
done
gh auth status > /dev/null 2>&1 || die "gh isn't signed in: run 'gh auth login'"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || die "can't find the GitHub repo"

# How long to wait, in seconds. The GitHub run takes about 15 to 25 minutes;
# Codemagic's TestFlight build about the same, sometimes longer.
find_run_timeout=180
testflight_timeout=3600

version_of() { grep -m1 '^version:' "$1" | sed 's/version: *//; s/+.*//' | tr -d '\r'; }

# --- Report on a tag that's already pushed -------------------------------
report() {
  local t="$1" ok=0 run sha conclusion jobs assets ios
  sha="$(git rev-list -n1 "refs/tags/$t" 2>/dev/null)" || { echo "No tag $t here (git fetch --tags?)"; return 1; }
  echo
  echo "Release $t (commit ${sha:0:7}):"

  run="$(gh run list --repo "$repo" --workflow release.yml --branch "$t" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)"
  if [ -z "$run" ]; then
    echo "  GitHub Release run: not found"
    ok=1
  else
    conclusion="$(gh run view "$run" --repo "$repo" --json conclusion -q .conclusion)"
    echo "  GitHub Release run $run: ${conclusion:-still running}"
    echo "    https://github.com/$repo/actions/runs/$run"
    jobs="$(gh run view "$run" --repo "$repo" --json jobs -q '.jobs[] | "    job \(.name): \(.conclusion // .status)"')"
    [ -n "$jobs" ] && echo "$jobs"
    [ "$conclusion" = "success" ] || ok=1
  fi

  assets="$(gh release view "$t" --repo "$repo" --json name,assets -q '"  GitHub Release: \(.name)", (.assets[] | "    \(.name)")' 2>/dev/null)"
  if [ -n "$assets" ]; then echo "$assets"; else echo "  GitHub Release: not found"; ok=1; fi

  ios="$(gh api "repos/$repo/commits/$sha/check-runs" -q '.check_runs[] | select(.name | test("TestFlight")) | "\(.status) \(.conclusion // "")"' 2>/dev/null | head -1)"
  case "$ios" in
    "completed success") echo "  iOS TestFlight (Codemagic): success (shows in TestFlight after Apple processes it)" ;;
    "") echo "  iOS TestFlight (Codemagic): no check found"; ok=1 ;;
    *) echo "  iOS TestFlight (Codemagic): $ios"; ok=1 ;;
  esac
  return $ok
}

if [ $status_only = 1 ]; then
  git fetch --quiet --tags origin 2> /dev/null
  report "$tag"
  exit $?
fi

# --- Checks before tagging (nothing is changed if one fails) ---------------
[[ "$tag" =~ ^[mv][0-9]+(\.[0-9]+)*$ ]] || die "tag '$tag' should look like m10, m10.1 or v1.0 (the Release workflow builds m* and v* tags)"
[ -n "$notes" ] || die "give the tester notes as the second argument (they go to Play, TestFlight and GitHub)"

git fetch --quiet --tags origin || die "git fetch failed"
git rev-parse -q --verify "refs/tags/$tag" > /dev/null && die "tag $tag already exists"
git diff --quiet && git diff --cached --quiet || die "tracked files have uncommitted changes: commit or stash them first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
  die "HEAD isn't origin/main: push your commits (git push origin main) or check out main"

phone_version="$(version_of controller_app/pubspec.yaml)"
tv_version="$(version_of tv_test_app/pubspec.yaml)"
[ "$phone_version" = "$tv_version" ] || die "versions differ: phone $phone_version, TV $tv_version"
for f in controller_app/lib/src/app_info.dart tv_test_app/lib/src/app_info.dart; do
  grep -q "appVersion = '$phone_version'" "$f" || die "$f doesn't say appVersion = '$phone_version'"
done

# Play shows at most 500 characters, including the "Thumb Party x (build n)" header.
build="$(git rev-list --count HEAD)"
header="Thumb Party $phone_version (build $build)"
room=$((500 - ${#header} - 2))
[ ${#notes} -le $room ] || die "notes are ${#notes} characters; Play allows $room after the header"

echo "Tag:      $tag on $(git log -1 --format='%h %s')"
echo "Version:  $phone_version, build $build"
echo "Notes:    $notes"
echo "Publishes to Play (both apps), TestFlight and a public GitHub Release."
if [ $yes = 0 ]; then
  printf 'Tag and push? [y/N] '
  if ! { read -r answer < /dev/tty; } 2> /dev/null; then
    echo
    echo "No terminal to ask in. Nothing done; add --yes to release without asking."
    exit 2
  fi
  case "$answer" in y | Y | yes) ;; *) echo "Nothing done."; exit 2 ;; esac
fi

# --- Tag and push --------------------------------------------------------
# The tag by its full name: a milestone's tag (m13) can share its name with the
# milestone's branch, and a bare name then matches both.
git tag -a "$tag" -m "$notes" || die "git tag failed"
if ! git push origin "refs/tags/$tag:refs/tags/$tag"; then
  git tag -d "$tag" > /dev/null
  die "push failed; the local tag was removed again"
fi
echo "Pushed $tag."
if [ $wait = 0 ]; then
  echo "Not waiting. Check later with: tools/release.sh --status $tag"
  exit 0
fi

# --- Wait for the builds ---------------------------------------------------
echo "Waiting for the GitHub Release run to start..."
run=""
for _ in $(seq 1 $((find_run_timeout / 10))); do
  run="$(gh run list --repo "$repo" --workflow release.yml --branch "$tag" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)"
  [ -n "$run" ] && break
  sleep 10
done
if [ -z "$run" ]; then
  echo "The Release run didn't start within $find_run_timeout s. Check https://github.com/$repo/actions"
  exit 1
fi
echo "Release run $run: https://github.com/$repo/actions/runs/$run (usually 15 to 25 minutes)"
gh run watch "$run" --repo "$repo" --exit-status --interval 30 > /dev/null 2>&1

echo "Waiting for Codemagic's TestFlight check..."
sha="$(git rev-list -n1 "refs/tags/$tag")"
waited=0
while [ $waited -lt $testflight_timeout ]; do
  state="$(gh api "repos/$repo/commits/$sha/check-runs" -q '.check_runs[] | select(.name | test("TestFlight")) | .status' 2>/dev/null | head -1)"
  [ "$state" = "completed" ] && break
  sleep 60
  waited=$((waited + 60))
done

report "$tag"
result=$?
[ $result = 0 ] && echo "All done." || echo "Something needs a look (above)."
exit $result
