#!/usr/bin/env bash
# Tests the dependency probe (tools/probe-deps.sh): a probe: stub patch that makes the workspace
# fail analyze may break only files in the allow: of a job of an EARLIER wave, so the job that
# holds the contract runs first (identity1 i1a's two new messages broke two switches in files no
# job allowed). One small git repo is built from fixtures/probe-deps in a temp folder; each case
# rewrites its batch, its analyze errors and its review output. pub get, analyze and review are
# stubs named by PROBE_PUB_CMD, PROBE_ANALYZE_CMD and PROBE_REVIEW_CMD, and PROBE_MAX_MIN=1 with
# RUN_LIMIT_UNIT_S=10 gives each probe job 10 s of limit; the timeout case lowers the unit to 1, so
# its one-minute limit runs out in one second, and every case ends in seconds.
# Each case also checks that the probe's worktree is gone (its temp folder is empty and the repo
# lists one worktree), so a leaked worktree fails the test.
#
#   bash tools/tests/probe-deps-test.sh
#
# Prints PASS <case> / FAIL <case> and the failing case's tool output, then RESULT; exits 1 when a
# case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
fix="$loc/tools/tests/fixtures/probe-deps"
tmp=$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/probe-deps-test-XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

cases=0
fails=0
out="$tmp/out.txt"
report() { # report <case> <0 passed | 1 failed>: on a failure, show the tool's output and the trees
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    echo "PASS $1"
    return 0
  fi
  echo "FAIL $1"
  fails=$((fails + 1))
  sed 's/^/    | /' "$out"
  git -C "$repo" worktree list 2>&1 | sed 's/^/    | /'
}

clean_after() { # clean_after: the probe's temp folder is empty and the repo lists one worktree
  [ -z "$(ls -A "$tool_tmp" 2> /dev/null)" ] &&
    [ "$(git -C "$repo" worktree list --porcelain | grep -c '^worktree ')" = 1 ]
}

tool_tmp="$tmp/tool-tmp"
mkdir -p "$tool_tmp"
pub_stub="$tmp/pub.sh"
analyze_stub="$tmp/analyze.sh"
sleep_stub="$tmp/analyze-sleep.sh"
review_stub="$tmp/review.sh"
cat > "$pub_stub" <<'EOF'
#!/usr/bin/env bash
echo pub >> "$PROBE_MARK"
echo "Got dependencies (stub)"
EOF
cat > "$analyze_stub" <<'EOF'
#!/usr/bin/env bash
echo "Analyzing (stub)"
while IFS= read -r where; do
  [ -n "$where" ] && echo "  error - $where - stub error - stub_code"
done < "$ANALYZE_ERRORS"
[ -s "$ANALYZE_ERRORS" ] && exit 1
echo "No issues found!"
exit 0
EOF
cat > "$sleep_stub" <<'EOF'
#!/usr/bin/env bash
echo "Analyzing (stub, slow)"
sleep 30
echo "No issues found!"
EOF
cat > "$review_stub" <<'EOF'
#!/usr/bin/env bash
cat "$REVIEW_OUT" 2> /dev/null
exit 0
EOF
chmod +x "$pub_stub" "$analyze_stub" "$sleep_stub" "$review_stub"
export PROBE_PUB_CMD="$pub_stub" PROBE_ANALYZE_CMD="$analyze_stub" PROBE_REVIEW_CMD="$review_stub"
export PROBE_MAX_MIN=1 RUN_LIMIT_UNIT_S=10 PROBE_POLL_S=0.1 PROBE_BASE=HEAD PROBE_REVIEW=0
export ANALYZE_ERRORS="$tmp/errors" REVIEW_OUT="$tmp/review.out" PROBE_MARK="$tmp/mark"

repo="$tmp/repo"
mkdir -p "$repo/tools" "$repo/src" "$repo/batch" "$repo/patches"
cp "$loc/tools/probe-deps.sh" "$repo/tools/"
cp "$fix/base/src/app.dart" "$fix/base/src/switch.dart" "$repo/src/"
cp "$fix/stub.patch" "$fix/noapply.patch" "$repo/patches/"
git -C "$repo" init -q && git -C "$repo" config user.email t@example.com &&
  git -C "$repo" config user.name t && git -C "$repo" add -A && git -C "$repo" commit -q -m base || exit 2

reset() { # reset: a fresh batch, analyze errors, review output and pub mark
  rm -f "$repo/batch"/*.md
  : > "$ANALYZE_ERRORS"
  : > "$REVIEW_OUT"
  : > "$PROBE_MARK"
  : > "$repo/batch/waves.txt"
}
brief() { # brief <job> <allow> [probe]: the batch's <job>.md, with a report: line like a real one
  printf 'job: probe test %s\nallow: %s\nreport: batch/%s-report.md\n' "$1" "$2" "$1" > "$repo/batch/$1.md"
  [ -z "${3:-}" ] || printf 'probe: %s\n' "$3" >> "$repo/batch/$1.md"
}
waves() { # waves <wave line>...: waves.txt, one line per argument
  printf '%s\n' "$@" > "$repo/batch/waves.txt"
}
errors() { # errors <file:line:col>...: what the analyze stub reports
  printf '%s\n' "$@" > "$ANALYZE_ERRORS"
}
run_probe() { # run_probe [args]: the tool from the fixture repo's root; sets rc
  rc=0
  ( cd "$repo" && TMPDIR="$tool_tmp" bash tools/probe-deps.sh "$@" ) > "$out" 2>&1 || rc=$?
}

# 1. Bad use is exit 2 with the RESULT line, and nothing is probed: no arguments, a folder that is
#    not there, a limit of 0 that must be refused rather than quietly replaced.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
run_probe
r=0
[ "$rc" = 2 ] && grep -qF 'RESULT: BAD INPUT' "$out" || r=1
report "no arguments is bad use (exit 2, RESULT: BAD INPUT)" "$r"
run_probe no-such-batch
r=0
[ "$rc" = 2 ] && grep -qF 'no such batch folder: no-such-batch' "$out" || r=1
report "a batch folder that is not there is bad use (exit 2)" "$r"
PROBE_MAX_MIN=0
export PROBE_MAX_MIN
run_probe batch
r=0
[ "$rc" = 2 ] && grep -qF 'RESULT: BAD INPUT: PROBE_MAX_MIN must be a whole number above 0' "$out" || r=1
report "PROBE_MAX_MIN=0 is bad use, never a quiet default (exit 2)" "$r"
PROBE_MAX_MIN=1
export PROBE_MAX_MIN

# 2. A batch whose briefs carry no probe: line says so and exits 0: there is nothing to probe.
reset
brief p 'src/app.dart'
brief q 'src/switch.dart'
waves 'p q'
run_probe batch
r=0
[ "$rc" = 0 ] && grep -qF 'no probe: line in batch' "$out" && grep -qF 'RESULT: ok' "$out" || r=1
report "a batch with no probe: line says so and exits 0" "$r"

# 3. A probe the workspace survives: pub get ran, no error file, exit 0 and the worktree is gone.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
run_probe batch
r=0
[ "$rc" = 0 ] && grep -qF 'PROBE p: 0 error files' "$out" && grep -qF 'RESULT: ok: 1 probe job(s)' "$out" &&
  [ -s "$PROBE_MARK" ] && clean_after || r=1
report "a clean probe is exit 0 (PROBE p: 0 error files), and its worktree is removed" "$r"

# 4. The real case: the stub breaks a switch in a file no job allows, so no job can fix it: FAIL.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
errors src/switch.dart:3:1
run_probe batch
r=0
[ "$rc" = 1 ] && grep -qF "FAIL deps p: src/switch.dart is in no job's allow" "$out" &&
  grep -qF 'RESULT: FAILED: 1 error file(s) of 1 probe job(s)' "$out" && clean_after || r=1
report "an error file in no job's allow is a FAIL (exit 1, the file named)" "$r"

# 5. A file allowed only by a job of the probe job's own wave is a dependence on that wave: FAIL.
reset
brief p 'src/app.dart' patches/stub.patch
brief s 'src/switch.dart'
waves 'p s'
errors src/switch.dart:3:1
run_probe batch
r=0
[ "$rc" = 1 ] && grep -qF 'is only in the allow of s, a job of the same wave 1' "$out" && clean_after || r=1
report "a file allowed only by a job of the same wave is a FAIL (exit 1, called a dependence)" "$r"

# 6. The same file in the probe job's own allow is the job's own work: no FAIL.
reset
brief p 'src/app.dart · src/switch.dart' patches/stub.patch
waves p
errors src/switch.dart:3:1
run_probe batch
r=0
[ "$rc" = 0 ] && ! grep -q '^FAIL' "$out" && grep -qF 'PROBE p: 1 error files' "$out" && clean_after || r=1
report "an error file the probe job allows is exit 0 (PROBE p: 1 error files)" "$r"

# 7. A file allowed only by a later wave's job breaks before that job runs: FAIL.
reset
brief p 'src/app.dart' patches/stub.patch
brief q 'src/switch.dart'
waves 'p' 'q'
errors src/switch.dart:3:1
run_probe batch
r=0
[ "$rc" = 1 ] && grep -qF 'is only in the allow of q, a later wave' "$out" && clean_after || r=1
report "a file allowed only by a later wave's job is a FAIL (exit 1)" "$r"

# 8. The patch's own file is exempt: the stub may break the file it adds, and it still counts.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
errors src/patched.dart:2:3
run_probe batch
r=0
[ "$rc" = 0 ] && ! grep -q '^FAIL' "$out" && grep -qF 'PROBE p: 1 error files' "$out" && clean_after || r=1
report "an error in the patch's own file is exempt (exit 0, still counted)" "$r"

# 9. A review.sh layers FAIL in a file the probe job allows is a WARN, not a FAIL.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
printf 'FAIL layers src/app.dart:3 a package imports the app (controller)\n' > "$REVIEW_OUT"
PROBE_REVIEW=1
export PROBE_REVIEW
run_probe batch
PROBE_REVIEW=0
export PROBE_REVIEW
r=0
[ "$rc" = 0 ] && grep -qF 'WARN layers p: src/app.dart:3 a package imports the app (controller)' "$out" &&
  grep -qF 'RESULT: ok' "$out" && clean_after || r=1
report "a layers FAIL in an allowed file is a WARN (exit 0, WARN line names the file)" "$r"

# 10. Analyze that passes PROBE_MAX_MIN is killed with its tree, exit 3, and the worktree is gone.
reset
brief p 'src/app.dart' patches/stub.patch
waves p
start_s=$SECONDS
PROBE_ANALYZE_CMD="$sleep_stub" RUN_LIMIT_UNIT_S=1
export PROBE_ANALYZE_CMD RUN_LIMIT_UNIT_S
run_probe batch
elapsed_s=$((SECONDS - start_s))
PROBE_ANALYZE_CMD="$analyze_stub" RUN_LIMIT_UNIT_S=10
export PROBE_ANALYZE_CMD RUN_LIMIT_UNIT_S
r=0
[ "$rc" = 3 ] && grep -qF 'RESULT: TIMEOUT: p passed PROBE_MAX_MIN=1 min' "$out" &&
  grep -qF 'its worktree was removed' "$out" && clean_after && [ "$elapsed_s" -lt 10 ] || r=1
report "a probe over PROBE_MAX_MIN is exit 3 and its worktree is removed (${elapsed_s}s)" "$r"

# 11. A patch that does not apply is setup failed (exit 3), never a pass, and nothing is left.
reset
brief p 'src/app.dart' patches/noapply.patch
waves p
run_probe batch
r=0
[ "$rc" = 3 ] && grep -qF "RESULT: SETUP FAILED: p: patches/noapply.patch doesn't apply" "$out" && clean_after || r=1
report "a patch that does not apply is setup failed (exit 3), not a pass" "$r"

# 12. A probe job that waves.txt does not list has no wave, so no dependence can be seen: bad use.
reset
brief p 'src/app.dart' patches/stub.patch
brief q 'src/switch.dart'
waves q
run_probe batch
r=0
[ "$rc" = 2 ] && grep -qF "doesn't list p" "$out" || r=1
report "a probe job missing from waves.txt is bad use (exit 2)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed (${SECONDS}s)"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed (${SECONDS}s)"
