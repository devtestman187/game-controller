#!/usr/bin/env bash
# Tests tools/check.sh's result cache (tools/check-cache.sh): a second run skips every suite whose inputs
# are unchanged since a passing run; a changed package reruns that suite and the suites that depend on it;
# a failed suite is never recorded; --no-cache and CHECK_CACHE=0 run everything; a changed pubspec.lock or
# tools/check.sh reruns all; a corrupt or missing cache file is ignored; -j 4 records and skips the same way.
#
#   bash tools/tests/check-cache-test.sh
#
# The copy is a temp git repo: check.sh, check-par.sh, check-cache.sh and affected.sh under tools/, and
# package folders with path dependencies: connection and kit depend on protocol, host on connection, arena
# on kit; look, metrics, puzzle, phone and tv depend on nothing. The dart and flutter stubs (CHECK_DART,
# CHECK_FLUTTER) log "<folder> <args>" to STUB_LOG; STUB_FAIL_SUITE names the folder whose test fails.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
src="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/check-cache-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp/tmp" # check.sh keeps its per-check logs here, removed with $tmp
mkdir -p "$TMPDIR" || exit 2

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show what check.sh printed.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fail "$1"
    sed 's/^/    | /' "$out"
  fi
}

out="$tmp/out.txt"
repo="$tmp/repo"
cache="$repo/.dart_tool/check-cache.tsv"
SUITES="protocol connection metrics kit look arena puzzle host phone tv"
ALL="arena connection host kit look metrics phone protocol puzzle tv" # the same ten, sorted

# The copy: the four scripts under tools/ and a git repo (the key reads the tree through git).
mkdir -p "$repo/tools"
for script in check.sh check-par.sh check-cache.sh affected.sh; do
  [ -f "$src/tools/$script" ] && cp "$src/tools/$script" "$repo/tools/$script"
done
git init -q "$repo"

# mk_pkg <folder> [dependency folder...]: a package with a pubspec.yaml (path dependencies) and a lib file.
mk_pkg() {
  local dir="$repo/$1" dep
  local name
  name="$(basename "$1")"
  shift
  mkdir -p "$dir/lib" "$dir/test"
  {
    echo "name: $name"
    echo "dependencies:"
    for dep in "$@"; do
      echo "  $(basename "$dep"):"
      echo "    path: ../$(basename "$dep")"
    done
  } > "$dir/pubspec.yaml"
  echo "// $name" > "$dir/lib/$name.dart"
}
mk_pkg packages/protocol
mk_pkg packages/connection packages/protocol
mk_pkg packages/metrics
mk_pkg packages/game_kit packages/protocol
mk_pkg packages/toy_look
mk_pkg packages/test_game packages/game_kit
mk_pkg packages/puzzle_game
mk_pkg packages/party_host packages/connection
mk_pkg controller_app
mk_pkg tv_test_app
echo "packages: {}" > "$repo/pubspec.lock"

# The stubs: a format or analyze call passes; a test call passes, or fails for STUB_FAIL_SUITE.
cat > "$tmp/stub-body.sh" <<'FIXTURE'
echo "$(basename "$PWD") $*" >> "${STUB_LOG:?}"
case "${1:-}" in
  format | analyze) rc=0 ;;
  *)
    if [ "$(basename "$PWD")" = "${STUB_FAIL_SUITE:-none}" ]; then
      echo "+1 -1: Some tests failed."
      echo "  Expected: the stub's rule"
      rc=1
    else
      echo "+1: All tests passed!"
      rc=0
    fi
    ;;
esac
exit "$rc"
FIXTURE
for tool in dart flutter; do
  printf '#!/usr/bin/env bash\n. "$(dirname "$0")/stub-body.sh"\n' > "$tmp/$tool"
  chmod +x "$tmp/$tool"
done

set_env() { # set_env [NAME=value ...]: a fresh stub environment, then these overrides
  unset CHECK_JOBS CHECK_FAIL_FAST CHECK_SKIP CHECK_CACHE
  export STUB_LOG="$tmp/calls.txt" CHECK_DART="$tmp/dart" CHECK_FLUTTER="$tmp/flutter" STUB_FAIL_SUITE=none
  for assignment in "$@"; do export "$assignment"; done
}

rc=0
run() { # run <check.sh args>: runs the copy on the stubs, storing rc and the output in $out
  : > "$STUB_LOG"
  rc=0
  bash "$repo/tools/check.sh" "$@" > "$out" 2>&1 || rc=$?
}
calls() { wc -l < "$STUB_LOG" | tr -d ' '; } # how many stub calls ran, format and analyze included
suite_of() { # suite_of <folder>: the check.sh suite name of a package folder
  case "$1" in
    game_kit) echo kit ;;
    toy_look) echo look ;;
    test_game) echo arena ;;
    puzzle_game) echo puzzle ;;
    party_host) echo host ;;
    controller_app) echo phone ;;
    tv_test_app) echo tv ;;
    *) echo "$1" ;;
  esac
}
ran() { # the suites whose test stub ran, sorted
  awk '$2 == "test" { print $1 }' "$STUB_LOG" | while read -r folder; do suite_of "$folder"; done |
    sort | tr '\n' ' ' | sed 's/ $//'
}
cached() { # the suites the output marks CACHED, sorted
  grep -E '^CACHED ' "$out" | awk '{ print $2 }' | sort | tr '\n' ' ' | sed 's/ $//'
}
cache_rows() { grep -cE "^[a-z]+"$'\t'"[0-9a-f]{40}"$'\t'"[0-9]+$" "$cache" 2> /dev/null; }
edit() { # edit <file under the copy>: appends a comment, so the tree sees a change and the file still runs
  case "$1" in
    *.dart) echo "// edit" >> "$repo/$1" ;;
    *) echo "# edit" >> "$repo/$1" ;;
  esac
}

# Case 1: a first run with no cache file runs all ten suites and records each one.
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ] && [ "$(cache_rows)" = 10 ]; then r=0; else r=1; fi
report "a first run with no cache file runs all ten suites and records ten passing rows" "$r"

# Case 2: a second run skips every suite: CACHED lines, exit 0, no test stub called.
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(cached)" = "$ALL" ] && [ "$(calls)" = 0 ] && grep -qE '^CACHED  protocol +\(passed [0-9]+s ago\)$' "$out" &&
  grep -q '^All checks passed (.*10 cached)' "$out"; then r=0; else r=1; fi
report "a second run prints ten CACHED lines, calls no stub, and exits 0" "$r"

# Case 3: a change in an unrelated package (toy_look) reruns that suite and nothing else.
edit packages/toy_look/lib/toy_look.dart
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "look" ] && [ "$(cached)" = "arena connection host kit metrics phone protocol puzzle tv" ]; then
  r=0
else
  r=1
fi
report "an edit in packages/toy_look reruns look only; the other nine are CACHED" "$r"

# Case 4: a change in protocol reruns protocol and its dependents (connection, kit, host, arena) only.
edit packages/protocol/lib/protocol.dart
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "arena connection host kit protocol" ] && [ "$(cached)" = "look metrics phone puzzle tv" ] &&
  [ "$(calls)" = 5 ]; then
  r=0
else
  r=1
fi
report "an edit in packages/protocol reruns protocol, connection, kit, host and arena (five stub calls)" "$r"

# Case 5: a failed suite is never recorded, so the next run (same files, no failure) reruns it.
edit packages/metrics/lib/metrics.dart
set_env STUB_FAIL_SUITE=metrics
run $SUITES
if [ "$rc" = 1 ] && grep -qE '^FAIL  metrics ' "$out" && grep -qE '^1 failed: metrics ' "$out"; then r=0; else r=1; fi
report "a failing metrics suite prints FAIL and exits 1" "$r"
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "metrics" ]; then r=0; else r=1; fi
report "after a failed metrics run, the next run reruns metrics (the failure was not recorded)" "$r"

# Case 6: --no-cache and CHECK_CACHE=0 run every suite, though the cache is full.
set_env
run --no-cache $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ] && [ "$(grep -c '^CACHED ' "$out")" = 0 ]; then r=0; else r=1; fi
report "--no-cache runs all ten suites and prints no CACHED line" "$r"
set_env CHECK_CACHE=0
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ] && [ "$(grep -c '^CACHED ' "$out")" = 0 ]; then r=0; else r=1; fi
report "CHECK_CACHE=0 runs all ten suites and prints no CACHED line" "$r"

# Case 7: a changed pubspec.lock or tools/check.sh reruns every suite.
set_env
run $SUITES
edit pubspec.lock
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ]; then r=0; else r=1; fi
report "a changed pubspec.lock reruns all ten suites" "$r"
set_env
run $SUITES
edit tools/check.sh
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ]; then r=0; else r=1; fi
report "a changed tools/check.sh reruns all ten suites" "$r"

# Case 8: a corrupt cache file is ignored: every suite runs, exit 0, and the next run skips them again.
set_env
run $SUITES
printf 'garbage\n\tno key\nprotocol\tnot-a-key\t12\n' > "$cache"
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ]; then r=0; else r=1; fi
report "a corrupt cache file is ignored and all ten suites run" "$r"
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(cached)" = "$ALL" ]; then r=0; else r=1; fi
report "after a corrupt cache file is rewritten, the next run skips all ten suites" "$r"

# Case 9: a missing cache file is ignored: every suite runs, and the file is written again.
rm -f "$cache"
set_env
run $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ] && [ "$(cache_rows)" = 10 ]; then r=0; else r=1; fi
report "a missing cache file is ignored: all ten suites run and the file is written again" "$r"

# Case 10: -j 4 records its passing suites, and the next -j 4 run skips every one of them.
rm -f "$cache"
set_env
run -j 4 $SUITES
if [ "$rc" = 0 ] && [ "$(ran)" = "$ALL" ] && [ "$(cache_rows)" = 10 ]; then r=0; else r=1; fi
report "-j 4 runs all ten suites and records ten passing rows" "$r"
set_env
run -j 4 $SUITES
if [ "$rc" = 0 ] && [ "$(cached)" = "$ALL" ] && [ "$(calls)" = 0 ]; then r=0; else r=1; fi
report "a second -j 4 run skips all ten suites and calls no stub" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
