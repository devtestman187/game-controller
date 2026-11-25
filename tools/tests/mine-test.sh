#!/usr/bin/env bash
# Tests tools/mine.sh and tools/churn.sh against the rules in
# docs/briefs/m16/process2/script-rules.md.
#
#   bash tools/tests/mine-test.sh
#
# Every case copies one base git worktree into a temp folder, copies
# tools/mine.sh and tools/churn.sh into it, and runs it from outside the
# repository. Stub dart/flutter commands log their calls and print canned
# output (STUB_OUT_DIR), so nothing reaches the real toolchain or the network.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
scripts="$(pwd)/tools"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/mine-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show what mine.sh printed.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fail "$1"
    sed 's/^/    | /' "$out"
  fi
}
last() { tail -n 1 "$out"; }

# The stubs: each logs "<name> <args>" and prints $STUB_OUT_DIR/<name>-<subcommand>.txt.
stub="$tmp/stub"
mkdir -p "$stub/out"
cat > "$stub/body.sh" <<'FIXTURE'
printf '%s %s\n' "$stub_name" "$*" >> "${STUB_LOG:?}"
out="${STUB_OUT_DIR:?}/$stub_name-$1"
[ -f "$out.txt" ] && cat "$out.txt"
[ -f "$out.hang" ] && exec sleep 30
[ -f "$out.churn" ] && printf 'regen\n' >> "$(cat "$out.churn")" # a test run rewrites a generated file
[ -f "$out.rc" ] && exit "$(cat "$out.rc")"
exit 0
FIXTURE
cat > "$stub/dart" <<'FIXTURE'
#!/usr/bin/env bash
stub_name=dart
. "$(dirname "$0")/body.sh"
FIXTURE
cat > "$stub/flutter" <<'FIXTURE'
#!/usr/bin/env bash
stub_name=flutter
. "$(dirname "$0")/body.sh"
FIXTURE
chmod +x "$stub/dart" "$stub/flutter"
reset_stub() { : > "$stub/log"; rm -f "$stub/out"/*; }

# The base worktree: a Flutter package, a plain Dart package, a package with no
# tests, one generated churn file and a README.
base="$tmp/base"
mkdir -p "$base/tools" "$base/app/lib" "$base/app/test" "$base/pure/lib" "$base/pure/test" "$base/bare/lib" \
  "$base/site/shots" "$base/tv_test_app/windows/flutter"
cp "$scripts/mine.sh" "$scripts/churn.sh" "$base/tools/"
printf 'name: app\n\nenvironment:\n  sdk: ^3.0.0\n  flutter: ">=3.0.0"\n\ndependencies:\n  flutter:\n    sdk: flutter\n' \
  > "$base/app/pubspec.yaml"
printf 'name: pure\n\nenvironment:\n  sdk: ^3.0.0\n\ndev_dependencies:\n  test: any\n' > "$base/pure/pubspec.yaml"
printf 'name: bare\n' > "$base/bare/pubspec.yaml"
printf "const screen = 'screen';\n" > "$base/app/lib/screen.dart"
printf "import 'package:app/screen.dart';\n\nvoid main() {}\n" > "$base/app/test/screen_test.dart"
printf 'const core = 1;\n' > "$base/pure/lib/core.dart"
printf "import 'package:pure/core.dart';\n\nvoid main() {}\n" > "$base/pure/test/core_test.dart"
printf 'const bare = 1;\n' > "$base/bare/lib/bare.dart"
printf 'generated\n' > "$base/site/shots/shot.png"
printf 'generated\n' > "$base/tv_test_app/windows/flutter/gen.cc"
printf '# base\n' > "$base/README.md"
printf '.dart_tool/\n' > "$base/.gitignore" # mine.sh keeps its lock there, as in the real repository
git init -q "$base" || exit 2
git -C "$base" add -A || exit 2
git -C "$base" -c user.name=mine-test -c user.email=mine-test@example.com commit -qm base || exit 2

repo() { # <case>: a fresh copy of the base worktree, its path in $repo_path
  repo_path="$tmp/repo-$1"
  cp -a "$base" "$repo_path"
  git -C "$repo_path" update-index -q --refresh 2> /dev/null
}
out="$tmp/out.txt"
rc=0
mine() { # <repo> [MINE_TIMEOUT]: runs its tools/mine.sh from outside the repository
  rc=0
  ( cd "$tmp" && STUB_LOG="$stub/log" STUB_OUT_DIR="$stub/out" DART="$stub/dart" FLUTTER="$stub/flutter" \
      MINE_TIMEOUT="${2:-60}" bash "$1/tools/mine.sh" ) > "$out" 2>&1 || rc=$?
}

repo no-change
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -q '^no changes' "$out" && last | grep -qF 'RESULT: ok:' &&
  [ ! -s "$stub/log" ]; then r=0; else r=1; fi
report "no changes prints a plain line, runs nothing and exits 0" "$r"

repo md-only
printf 'more\n' >> "$repo_path/README.md"
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && [ ! -s "$stub/log" ] && last | grep -qF 'RESULT: ok:'; then r=0; else r=1; fi
report "a .md-only change runs no dart command and exits 0" "$r"

repo deleted-lib
git -C "$repo_path" rm -q app/lib/screen.dart
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -qF 'flutter test test/screen_test.dart' "$stub/log" &&
  ! grep -qF 'format app/lib/screen.dart' "$stub/log"; then r=0; else r=1; fi
report "a deleted lib file's surviving test still runs, the file isn't formatted" "$r"

repo deleted-test
git -C "$repo_path" rm -q pure/test/core_test.dart
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -qF 'NO TESTS pure' "$out" && ! grep -q ' test ' "$stub/log"; then r=0; else r=1; fi
report "a deleted test is not run and its package prints NO TESTS" "$r"

repo renamed
git -C "$repo_path" mv app/lib/screen.dart app/lib/home.dart
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -qF 'format app/lib/home.dart' "$stub/log" &&
  ! grep -qF 'format app/lib/screen.dart' "$stub/log" &&
  grep -qF 'flutter test test/screen_test.dart' "$stub/log"; then r=0; else r=1; fi
report "a renamed file is formatted under its new path (and its tests still run)" "$r"

repo spaces
printf 'const spaced = 1;\n' > "$repo_path/app/lib/with space.dart"
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -qF 'format app/lib/with space.dart' "$stub/log"; then r=0; else r=1; fi
report "a path with spaces is formatted as one argument" "$r"

repo bare-pkg
printf 'const bare = 2;\n' > "$repo_path/bare/lib/bare.dart"
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && grep -qF 'NO TESTS bare' "$out"; then r=0; else r=1; fi
report "a package with no tests prints a NO TESTS line" "$r"

repo failing
printf '// touched\n' >> "$repo_path/app/test/screen_test.dart"
reset_stub
cat > "$stub/out/flutter-test.txt" <<'FIXTURE'
00:02 +1 -1: test/screen_test.dart: widget test name [E]
  Expected: <true>
  Actual: <false>
  detail 3
  detail 4
  detail 5
  detail 6
  detail 7
  detail 8
  detail 9
00:02 +1 -1: Some tests failed.
FIXTURE
printf '1\n' > "$stub/out/flutter-test.rc"
mine "$repo_path"
if [ "$rc" = 1 ] && grep -qF 'FAILED test/screen_test.dart: widget test name' "$out" &&
  grep -qF 'detail 8' "$out" && ! grep -qF 'detail 9' "$out" && last | grep -qF 'RESULT: FAILED:'; then r=0; else r=1; fi
report "a failing test prints its name and the first 8 lines, exit 1" "$r"

repo hang
printf '// touched\n' >> "$repo_path/app/lib/screen.dart"
reset_stub
printf 'hang\n' > "$stub/out/dart-analyze.hang"
start=$(date +%s)
mine "$repo_path" 3
secs=$(($(date +%s) - start))
if [ "$rc" = 2 ] && grep -q '^TIMEOUT: ' "$out" && last | grep -qF 'RESULT: TIMEOUT:' &&
  [ "$secs" -ge 3 ] && [ "$secs" -lt 20 ]; then r=0; else r=1; fi
report "a hanging command is stopped by MINE_TIMEOUT=3 (exit 2, ${secs}s)" "$r"

repo locked
mkdir -p "$repo_path/.dart_tool"
printf '%s\n' "$$" > "$repo_path/.dart_tool/mine.lock"
reset_stub
mine "$repo_path"
if [ "$rc" = 3 ] && grep -qF 'another mine.sh is running' "$out" && last | grep -qF 'RESULT: BAD INPUT:' &&
  [ "$(cat "$repo_path/.dart_tool/mine.lock" 2> /dev/null)" = "$$" ]; then r=0; else r=1; fi
report "a second copy on a live lock is refused (exit 3) and keeps the lock" "$r"

printf '999999\n' > "$repo_path/.dart_tool/mine.lock"
reset_stub
mine "$repo_path"
if [ "$rc" = 0 ] && last | grep -qF 'RESULT: ok:' && [ ! -e "$repo_path/.dart_tool/mine.lock" ]; then r=0; else r=1; fi
report "a stale lock is replaced and removed" "$r"

repo churn
printf '// dirty\n' >> "$repo_path/app/lib/screen.dart"
reset_stub
printf '%s' "$repo_path/tv_test_app/windows/flutter/gen.cc" > "$stub/out/flutter-test.churn" # dirtied by the run itself
mine "$repo_path"
status="$(git -C "$repo_path" status --porcelain)"
if [ "$rc" = 0 ] && grep -qF 'churn: reverted 1 generated file(s)' "$out" &&
  printf '%s' "$status" | grep -q '^ M app/lib/screen.dart$' && ! printf '%s' "$status" | grep -q 'gen.cc'; then r=0; else r=1; fi
report "the churn file the run dirtied is reverted and the person's file is left alone" "$r"

# A churn file that was already dirty when mine.sh started (a person's edit, or an earlier run's) is not reverted.
repo churn_before
printf 'my edit\n' >> "$repo_path/tv_test_app/windows/flutter/gen.cc"
reset_stub
printf '%s' "$repo_path/tv_test_app/windows/flutter/gen.cc" > "$stub/out/flutter-test.churn"
mine "$repo_path"
status="$(git -C "$repo_path" status --porcelain)"
if [ "$rc" = 0 ] && ! grep -qF 'churn: reverted' "$out" && printf '%s' "$status" | grep -q 'gen.cc' &&
  grep -q 'my edit' "$repo_path/tv_test_app/windows/flutter/gen.cc"; then r=0; else r=1; fi
report "a churn file already dirty at the start is left alone (the pre-run snapshot)" "$r"

repo interrupt
printf '// touched\n' >> "$repo_path/app/lib/screen.dart"
reset_stub
printf 'hang\n' > "$stub/out/dart-analyze.hang"
tmproot="$tmp/tmproot"
mkdir -p "$tmproot"
( cd "$tmp" && TMPDIR="$tmproot" STUB_LOG="$stub/log" STUB_OUT_DIR="$stub/out" DART="$stub/dart" \
    FLUTTER="$stub/flutter" MINE_TIMEOUT=60 timeout 4 bash "$repo_path/tools/mine.sh" ) > "$out" 2>&1
rct=$?
if [ "$rct" = 124 ] && [ ! -e "$repo_path/.dart_tool/mine.lock" ] &&
  [ -z "$(ls -A "$tmproot" 2> /dev/null)" ]; then r=0; else r=1; fi
report "an interrupted run removes its lock and temp files (killed after 4s)" "$r"

mkdir -p "$tmp/notrepo/tools"
cp "$scripts/mine.sh" "$scripts/churn.sh" "$tmp/notrepo/tools/"
reset_stub
rc=0
( cd "$tmp" && STUB_LOG="$stub/log" STUB_OUT_DIR="$stub/out" DART="$stub/dart" FLUTTER="$stub/flutter" \
    bash "$tmp/notrepo/tools/mine.sh" ) > "$out" 2>&1 || rc=$?
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: not a git worktree' && [ ! -s "$stub/log" ]; then r=0; else r=1; fi
report "a folder outside a git worktree is bad input (exit 3)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
