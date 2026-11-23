#!/usr/bin/env bash
# Tests the combined check's scope and format, in tools/run-scope.sh, which checks() in tools/run-steps.sh
# calls with the wave's job names. The suites no change of the wave reaches are skipped (the real
# tools/affected.sh --not, run on a temp repo whose check.sh stub lists packages a and b); the tools suite
# follows its own rule; RUN_CHECK_FULL=1 skips nothing but that rule; a failing or missing affected.sh skips
# no suite for its paths (WARN); the allowed .dart files that dart format wants changed are formatted (dart
# stubbed) and the others are not touched; check.sh runs with -j 4. Also: tools/run-wave.sh's turn_cap still
# accepts an over-cap job with result 0 and its report (WARN), read from a fake usage row by run-jobs.sh's usage.
#
#   bash tools/tests/run-affected-test.sh
#
# Every case works in a temp folder; dart, check.sh and review.sh are stubs, so no real check runs. Prints
# PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
src="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-affected-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
out="$tmp/out.txt"
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show the output the case left in $out
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

# The dart stub logs its arguments to STUB_LOG. With --set-exit-if-changed it exits 1 for a file that holds
# the marker UNFORMATTED; a plain format rewrites such a file to "formatted".
mkdir -p "$tmp/bin"
cat > "$tmp/bin/dart" <<'STUB'
#!/usr/bin/env bash
echo "dart $*" >> "${STUB_LOG:?}"
last="${*: -1}"
if [[ " $* " == *" --set-exit-if-changed "* ]]; then
  grep -q UNFORMATTED "$last" && exit 1
  exit 0
fi
grep -q UNFORMATTED "$last" && printf 'formatted\n' > "$last"
exit 0
STUB
chmod +x "$tmp/bin/dart"

# scope_repo <name>: a fresh temp git repo with the real tools/affected.sh, the check.sh and review.sh stubs,
# packages a and b, and two job briefs (j1 allows packages/a/lib/x.dart, j2 packages/b/lib/z.dart), all committed,
# so that a case's own change is the only one git status shows. Sets repo.
scope_repo() {
  repo="$tmp/scope-$1"
  mkdir -p "$repo/tools" "$repo/packages/a/lib" "$repo/packages/b/lib" "$repo/batch"
  cp "$src/tools/affected.sh" "$repo/tools/affected.sh"
  cat > "$repo/tools/check.sh" <<'STUB'
#!/usr/bin/env bash
# The stub check.sh: --list prints the suite table in check.sh's shape; a run logs CHECK_SKIP and its arguments.
if [ "${1:-}" = --list ]; then
  printf '%-11s %-22s %s\n' format . x analyze . x a packages/a x b packages/b x tools . x
  exit 0
fi
echo "skip=${CHECK_SKIP-unset} args=$*" >> "${SKIP_LOG:?}"
exit 0
STUB
  printf '#!/usr/bin/env bash\nexit 0\n' > "$repo/tools/review.sh"
  chmod +x "$repo/tools/affected.sh" "$repo/tools/check.sh" "$repo/tools/review.sh"
  printf 'allow: packages/a/lib/x.dart · batch/j1-report.md\nreport: batch/j1-report.md\nturns: 30\n' > "$repo/batch/j1.md"
  printf 'allow: packages/b/lib/z.dart · batch/j2-report.md\nreport: batch/j2-report.md\n' > "$repo/batch/j2.md"
  printf 'void a() {}\n' > "$repo/packages/a/lib/x.dart"
  printf 'void b() {}\n' > "$repo/packages/b/lib/y.dart"
  printf 'void z() {}\n' > "$repo/packages/b/lib/z.dart"
  git -C "$repo" init -q
  git -C "$repo" add -A
  git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm base
}

# run_scope <repo> <full: 0 | 1> <job>...: runs checks() of tools/run-steps.sh in the repo, with the jobs as one
# string (as tools/run-jobs.sh passes them) and RUN_CHECK_FULL=1 when full is 1. Sets rc, skip_log, notes,
# dart_log, and out (the three logs together, for a failing report).
run_scope() {
  local dir=$1 full=$2 name
  name=$(basename "$dir")
  shift 2
  skip_log="$tmp/$name-skip.txt"
  notes="$tmp/$name-notes.txt"
  dart_log="$tmp/$name-dart.txt"
  out="$tmp/$name-out.txt"
  : > "$skip_log"
  : > "$notes"
  : > "$dart_log"
  (
    cd "$dir" || exit 2
    unset CHECK_SKIP RUN_CHECK_SKIP RUN_CHECK_FULL
    [ "$full" = 1 ] && export RUN_CHECK_FULL=1
    export PATH="$tmp/bin:$PATH" STUB_LOG="$dart_log" SKIP_LOG="$skip_log"
    WORK="$tmp/work-$name"
    B="$dir/batch"
    mkdir -p "$WORK"
    SIZE_STOP=380
    . "$src/tools/run-steps.sh"
    note() { echo "NOTE: $*" >> "$notes"; }
    stop() { echo "STOP: $*" >> "$notes"; exit 1; }
    unchurn() { :; }
    check_stop() { :; }
    kill_tree() { :; }
    checks "$*"
  ) > "$tmp/$name-run.txt" 2>&1
  rc=$?
  cat "$skip_log" "$notes" "$dart_log" > "$out"
}

# Case 1: a wave changing only packages/a runs a's suites; the others and the tools suite are skipped.
scope_repo a-only
printf 'void a() { }\n' > "$repo/packages/a/lib/x.dart"
run_scope "$repo" 0 j1
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = "skip=b tools args=-j 4" ] &&
  [ "$(grep -c 'combined check' "$notes")" = 1 ] &&
  grep -qxF "NOTE: combined check: skips b tools (no job's change reaches them)" "$notes"; then r=0; else r=1; fi
report "a wave changing only packages/a skips b and tools, runs check.sh -j 4, and logs one combined-check line" "$r"

# Case 2: RUN_CHECK_FULL=1 skips nothing but the tools suite, which still follows its rule.
scope_repo full
printf 'void a() { }\n' > "$repo/packages/a/lib/x.dart"
run_scope "$repo" 1 j1
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = "skip=tools args=-j 4" ] &&
  [ "$(grep -c 'combined check' "$notes")" = 1 ] &&
  grep -qxF "NOTE: combined check: the tools suite is skipped (no job changed a file under tools/)" "$notes"; then r=0; else r=1; fi
report "RUN_CHECK_FULL=1 skips no suite but the tools suite (no job changed a file under tools/)" "$r"

# Case 3: a wave touching tools/check.sh runs every suite, the tools suite included.
scope_repo tools-change
printf '# changed\n' >> "$repo/tools/check.sh"
run_scope "$repo" 0 j1
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = "skip= args=-j 4" ] &&
  [ "$(grep -c 'combined check' "$notes")" = 1 ] &&
  grep -qxF "NOTE: combined check: the tools suite runs (a job changed a file under tools/)" "$notes"; then r=0; else r=1; fi
report "a wave touching tools/check.sh runs every suite, the tools suite included, with one log line" "$r"

# Case 4: a failing tools/affected.sh skips no suite for its paths: WARN, and the tools rule still applies.
scope_repo affected-fails
printf 'void a() { }\n' > "$repo/packages/a/lib/x.dart"
printf '#!/usr/bin/env bash\nexit 2\n' > "$repo/tools/affected.sh"
git -C "$repo" add tools/affected.sh
git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm "a broken affected.sh is in the base"
run_scope "$repo" 0 j1
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = "skip=tools args=-j 4" ] &&
  grep -q '^NOTE: WARN: tools/affected.sh failed or is missing' "$notes"; then r=0; else r=1; fi
report "a failing tools/affected.sh WARNs and runs every suite (only the tools rule skips one)" "$r"

# Case 5: a missing tools/affected.sh behaves as a failing one.
scope_repo affected-missing
printf 'void a() { }\n' > "$repo/packages/a/lib/x.dart"
git -C "$repo" rm -q tools/affected.sh
git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm "affected.sh is missing from the base"
run_scope "$repo" 0 j1
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = "skip=tools args=-j 4" ] &&
  grep -q '^NOTE: WARN: tools/affected.sh failed or is missing' "$notes"; then r=0; else r=1; fi
report "a missing tools/affected.sh WARNs and runs every suite (only the tools rule skips one)" "$r"

# Cases 6 and 7: the allowed .dart files that dart format wants are formatted and logged for their job; the
# .dart file no job allows (packages/b/lib/y.dart) is not touched.
scope_repo format
printf 'UNFORMATTED\n' > "$repo/packages/a/lib/x.dart"
printf 'UNFORMATTED\n' > "$repo/packages/b/lib/z.dart"
printf 'UNFORMATTED\n' > "$repo/packages/b/lib/y.dart"
run_scope "$repo" 0 j1 j2
if [ "$rc" = 0 ] && grep -qxF 'dart format packages/a/lib/x.dart' "$dart_log" &&
  grep -qxF 'dart format packages/b/lib/z.dart' "$dart_log" &&
  grep -qxF "NOTE: formatted packages/a/lib/x.dart for j1" "$notes" &&
  grep -qxF "NOTE: formatted packages/b/lib/z.dart for j2" "$notes" &&
  [ "$(cat "$repo/packages/a/lib/x.dart")" = formatted ]; then r=0; else r=1; fi
report "an allowed .dart file that dart format wants changed is formatted and logged for its job" "$r"
if ! grep -q 'y.dart' "$dart_log" && grep -qxF UNFORMATTED "$repo/packages/b/lib/y.dart"; then r=0; else r=1; fi
report "a .dart file outside every allow: is not touched" "$r"

# Case 8: turn_cap still accepts an over-cap job with result 0 and its report (a WARN). The usage row is fake: 40
# turns against the brief's turns: 30. (At result 1 turn_cap returns 1 and finished_job parks the job.)
tc="$(cd "$tmp" && pwd)/turn" # a POSIX path: awk -v reads the backslashes of a Windows one as escapes
mkdir -p "$tc/batch"
printf 'allow: src/x.dart · batch/j1-report.md\nturns: 30\n' > "$tc/batch/j1.md"
printf '## Summary\n\nstub report\n' > "$tc/batch/j1-report.md"
printf 'a\tb\t40\t1200\tc\td\te\tf\tg\t%s\n' "$tc/batch/j1.md" > "$tc/usage.tsv"
turn_out=$(
  B="$tc/batch"
  FLASH_USAGE_LOG="$tc/usage.tsv"
  note() { echo "NOTE: $*"; }
  . "$src/tools/run-wave.sh"
  eval "$(sed -n '/^usage() {/,/^}/p' "$src/tools/run-jobs.sh")"
  turn_cap j1 0
  echo "RETURN: $?"
)
printf '%s\n' "$turn_out" > "$out"
if grep -qxF 'NOTE: WARN: job j1 used 40 turns, over its cap of 30 (its own checks passed; accepted)' "$out" &&
  grep -qxF 'RETURN: 0' "$out"; then r=0; else r=1; fi
report "turn_cap accepts an over-cap job with result 0 and its report, with a WARN" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
