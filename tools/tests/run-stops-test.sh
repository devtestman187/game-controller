#!/usr/bin/env bash
# Reproduces the stop classes of docs/briefs/m16/wave2-789/run.log (tune3 job 1), so the tooling fixes
# of jobs 2-7 have a test that failed first:
#   rc4-churn-over-cap   a job whose own run ended with result 4 (only generated churn outside its list)
#                        and that is over its turn cap: the churn is dropped first, then it is accepted
#                        (it was parked: n9b1, n8c, n8b2, f4)
#   over-cap-verified    a job over its cap with result 0 and a report is accepted only after the runner's
#                        own format/analyze (the brief's check: line) passes; an incomplete one is parked (f2)
#   parked-diff-out      a parked job's files leave the tree and are saved as a patch, so the combined check of
#                        its siblings does not fail on them (n8b3, n8e2, n8e3)
#   pause-restart        RUN_PAUSE_AFTER_WAVE=1: a restart runs the next wave, it does not pause again
#   waiter-fresh-start   tools/wait-run.sh ignores the STOPPED line of the run before the last `start at`
#   resumed-turns        a job whose usage row covers the last resume only (1 turn, 0 min) gets a WARN line
# The fixture repo, stub worker and stub tools are those of run-wave-test.sh; RUN_LIMIT_UNIT_S=1 makes a
# "minute" a second. Brief lines the stub worker reads: stub-sleep: <s>, stub-rc: <n>, stub-write: <path>
# (a file it leaves in the tree, as flash.sh would apply a finished job), stub-outside: yes (result 4 with the
# generated churn block and a kept worktree, as flash.sh prints it).
#
#   bash tools/tests/run-stops-test.sh
set -u
# The caller's run settings must not reach the runner (RUN_PAUSE_AFTER_WAVE leaked into two tests, Nov 25).
for v in $(compgen -e | grep -E '^(RUN_|STUB_|BRIEF_CHECK|CHECK_|WAIT_)'); do unset "$v"; done
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-stops-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0
out="$tmp/out.txt" rc=0 batch="docs/briefs/fix" repo="" work=""
report() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); sed 's/^/    | /' "$out"; fi; }
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\necho "$0 $*" >> "${STUB_TOOLS_LOG:-/dev/null}"\nexit 0\n' > "$tmp/bin/flutter"
cp "$tmp/bin/flutter" "$tmp/bin/dart"
real_sleep=$(command -v sleep)
printf '#!/usr/bin/env bash\ncase "${1:-}" in 25) exec "%s" 1 ;; *) exec "%s" "$@" ;; esac\n' "$real_sleep" "$real_sleep" > "$tmp/bin/sleep"
chmod +x "$tmp/bin/"*
cat > "$tmp/flash-stub.sh" <<'EOS'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
brief=${2:-}
f() { sed -n "s/^$1: *//p" "$brief" | head -n 1; }
nap=$(f stub-sleep); [ -n "$nap" ] && sleep "$nap"
w=$(f stub-write); [ -n "$w" ] && { mkdir -p "$(dirname "$w")"; printf '%s\n' "${STUB_CONTENT:-job}" >> "$w"; }
rep=$(f report)
[ "$(f stub-noreport)" = yes ] || { mkdir -p "$(dirname "$rep")" && printf '## Summary\n\nstub report\n' > "$rep"; }
code=$(f stub-rc); code=${code:-0}
if [ "$(f stub-outside)" = yes ]; then
  echo "---- flash: CHANGED FILES OUTSIDE --allow (src/app.dart tv_test_app/windows/flutter/generated_plugins.cmake):"
  echo "  tv_test_app/windows/flutter/generated_plugins.cmake"
  echo "---- flash: changes NOT applied here; the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"; code=4
fi
exit "$code"
EOS
chmod +x "$tmp/flash-stub.sh"
export FLASH_CMD="$tmp/flash-stub.sh"
stubs() {
  cat > "$repo/tools/check.sh" <<'EOS'
#!/usr/bin/env bash
echo "check $* (stub)" >> "${STUB_TOOLS_LOG:-/dev/null}"
if grep -qs BROKEN src/app.dart; then echo "FAIL format"; exit 1; fi
if [ -e src/parked.txt ]; then echo "FAIL tests: parked job file in the tree"; exit 1; fi
echo "check ok (stub)"
EOS
  printf '#!/usr/bin/env bash\necho "RESULT: ok: nothing to report (stub)"\n' > "$repo/tools/review.sh"
  printf '#!/usr/bin/env bash\ngit add -A && git commit -q -m "job: $(basename "$1" .md)" && echo "Committed: stub"\n' > "$repo/tools/commit-job.sh"
  printf '#!/usr/bin/env bash\nprintf "STOP (stub)\\ncause: %%s\\n" "${3:-}" > "${1%%/}/STOP.md"\necho "RESULT: ok: STOP.md written (stub)"\n' > "$repo/tools/run-stop.sh"
  chmod +x "$repo"/tools/*.sh
}
template="$tmp/template/repo"
repo="$template"
mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$repo/tv_test_app/windows/flutter"
cp "$loc"/tools/run-jobs.sh "$loc"/tools/run-steps.sh "$loc"/tools/run-review.sh "$loc"/tools/churn.sh \
  "$loc"/tools/run-limits.sh "$loc"/tools/run-wave.sh "$repo/tools/"
for opt in run-capcheck.sh; do [ -f "$loc/tools/$opt" ] && cp "$loc/tools/$opt" "$repo/tools/"; done
stubs
printf 'base\n' > "$repo/src/app.dart"
printf 'base\n' > "$repo/tv_test_app/windows/flutter/generated_plugins.cmake"
printf '{}\n' > "$repo/.dart_tool/package_config.json"
git -C "$repo" init -q && git -C "$repo" config core.autocrlf false && git -C "$repo" config user.email t@example.com && git -C "$repo" config user.name t
git -C "$repo" add -A && git -C "$repo" commit -q -m base || exit 2
fixture() { # fixture <case>: a copy of the template with default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"; mkdir -p "$base" "$work"; cp -r "$template" "$repo" || exit 2
  export STUB_MARK="$base/flash-ran" STUB_TOOLS_LOG="$base/tools.log" STUB_TREE="$base/tree" PREFLIGHT_SKIP=1
  export FLASH_USAGE_LOG="$base/usage.tsv" RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  : > "$FLASH_USAGE_LOG"
}
brief() { # brief <job> [extra lines...]: allow src/app.dart, report <job>-report.md
  local j=$1; shift
  { printf 'allow: src/app.dart · %s/%s-report.md\nreport: %s/%s-report.md\ncheck: format analyze\nexpected-min: 20\n' "$batch" "$j" "$batch" "$j"; printf '%s\n' "$@"; } > "$repo/$batch/$j.md"
}
waves() { printf '%s\n' "$@" > "$repo/$batch/waves.txt"; git -C "$repo" add -A && git -C "$repo" commit -q -m briefs; }
row() { printf 'job\t0\t%s\t%s\t0\t0\t0\t0\t0\t%s/%s.md\n' "$2" "$3" "$batch" "$1" >> "$FLASH_USAGE_LOG"; } # row <job> <turns> <seconds>
run_jobs() { rc=0; ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" timeout -k 5 60 bash tools/run-jobs.sh "$batch" --no-review "$@" ) > "$out" 2>&1 || rc=$?; }
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; }
done_has() { grep -q "^$1 " "$repo/$batch/done.txt" 2>/dev/null; }
last_line() { tail -n 1 "$out"; }

# 1. rc-4 churn on a job over its cap: the churn is dropped, the job's own file applied, and the job accepted.
fixture rc4cap
brief churny "turns: 5" "stub-outside: yes"
waves churny; row churny 8 60
cp -r "$repo" "$STUB_TREE" && printf 'changed\n' > "$STUB_TREE/src/app.dart" &&
  printf 'regen\n' > "$STUB_TREE/tv_test_app/windows/flutter/generated_plugins.cmake"
run_jobs
if [ "$rc" = 0 ] && done_has churny && logged "committed churny" && ! logged "(parked" && grep -q changed "$repo/src/app.dart"; then r=0; else r=1; fi
report "rc-4 churn is handled before the turn cap: a job over its cap with only generated churn outside is accepted (exit 0)" "$r"

# 2. The same job under its cap (regression: this already worked).
fixture rc4under
brief churny "turns: 50" "stub-outside: yes"
waves churny; row churny 8 60
cp -r "$repo" "$STUB_TREE" && printf 'changed\n' > "$STUB_TREE/src/app.dart"
run_jobs
if [ "$rc" = 0 ] && done_has churny; then r=0; else r=1; fi
report "rc-4 churn under the cap is accepted (exit 0)" "$r"

# 3. Over the cap with result 0 and a report: the runner checks it itself (check: format analyze), and an
#    incomplete job (its own run left a broken tree) is parked, while its clean sibling is committed.
fixture capverify
brief bad "turns: 5" "stub-write: src/app.dart"
printf 'allow: src/good.txt · %s/good-report.md\nreport: %s/good-report.md\ncheck: format analyze\nexpected-min: 20\nstub-write: src/good.txt\n' "$batch" "$batch" > "$repo/$batch/good.md"
waves "bad good"; row bad 8 60
STUB_CONTENT=BROKEN run_jobs
if [ "$rc" = 1 ] && logged "committed good" && ! logged "committed bad" && ! done_has bad &&
  grep -q "check format analyze" "$STUB_TOOLS_LOG" && ! grep -q BROKEN "$repo/src/app.dart"; then r=0; else r=1; fi
report "an over-cap job is checked by the runner before it is accepted; a broken one is parked, its sibling committed" "$r"

# 4. A parked job's files are saved as a patch and leave the tree: its sibling's combined check passes.
fixture parkdiff
printf 'allow: src/parked.txt · %s/pk-report.md\nreport: %s/pk-report.md\nexpected-min: 20\nturns: 5\nstub-write: src/parked.txt\nstub-rc: 1\n' "$batch" "$batch" > "$repo/$batch/pk.md"
brief sib
waves "pk sib"; row pk 8 60
run_jobs
if [ "$rc" = 1 ] && logged "committed sib" && done_has sib && ! done_has pk && [ ! -e "$repo/src/parked.txt" ] &&
  grep -qs "src/parked.txt" "$work/parked-pk.patch" &&
  [ "$(last_line)" = "RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): pk (their logs: $batch/flash-<job>.log)" ]; then r=0; else r=1; fi
report "a parked job's diff is saved to the work folder and removed from the tree, so the sibling's combined check passes" "$r"

# 4b. A parked job's allow: files that a sibling lists too, or that were dirty before the run, stay in the tree.
fixture parkshare
mkdir -p "$repo/site/shots" && printf 'base\n' > "$repo/site/shots/dirty.png" && git -C "$repo" add -A && git -C "$repo" commit -q -m dirtybase || exit 2
printf 'edit\n' > "$repo/site/shots/dirty.png"
printf 'allow: src/parked.txt · src/shared.txt · site/shots/dirty.png · %s/pk-report.md\nreport: %s/pk-report.md\nexpected-min: 20\nturns: 5\nstub-sleep: 2\nstub-write: src/parked.txt\nstub-rc: 1\n' "$batch" "$batch" > "$repo/$batch/pk.md"
printf 'allow: src/shared.txt · %s/sib-report.md\nreport: %s/sib-report.md\ncheck: format analyze\nexpected-min: 20\nstub-write: src/shared.txt\n' "$batch" "$batch" > "$repo/$batch/sib.md"
waves "pk sib"; row pk 8 60
run_jobs
if [ "$rc" = 1 ] && logged "committed sib" && done_has sib && ! done_has pk && [ ! -e "$repo/src/parked.txt" ] &&
  git -C "$repo" ls-tree -r --name-only HEAD | grep -qx src/shared.txt && grep -qx edit "$repo/site/shots/dirty.png" &&
  [ "$(last_line)" = "RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): pk (their logs: $batch/flash-<job>.log)" ]; then r=0; else r=1; fi
report "a parked job keeps a sibling's shared file and its own pre-run dirty file in the tree; only its own new file leaves" "$r"

# 5. RUN_PAUSE_AFTER_WAVE=1 (reviews on): the run pauses after wave 1; the restart runs wave 2 and does not pause again.
fixture pause
brief w1j; brief w2j
waves w1j w2j
rc=0; ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" RUN_PAUSE_AFTER_WAVE=1 timeout -k 5 60 bash tools/run-jobs.sh "$batch" ) > "$out" 2>&1 || rc=$?
first=$rc
rc=0; ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" RUN_PAUSE_AFTER_WAVE=1 timeout -k 5 60 bash tools/run-jobs.sh "$batch" ) > "$out" 2>&1 || rc=$?
if [ "$first" = 1 ] && grep -q "PAUSED after wave 1" "$repo/$batch/run.log" && done_has w1j && done_has w2j &&
  ! grep -q "PAUSED after wave 2" "$repo/$batch/run.log" && logged "committed w2j" && [ "$rc" = 0 ]; then r=0; else r=1; fi
report "a restart after a pause runs the next wave and does not pause again (first exit $first, second $rc)" "$r"

# 5b. A session that resumed (usage row: 1 turn, 2 s) for a job that ran 6+ minutes (seconds here): a WARN line names it.
fixture resumed
brief rj "stub-sleep: 6"
waves rj; row rj 1 2
run_jobs
if [ "$rc" = 0 ] && logged "WARN: rj logged 1 turns, 0 min but ran " && logged "last resume only"; then r=0; else r=1; fi
report "a usage row that covers the last resume only gets a WARN with the job's wall time" "$r"

# 6. wait-run.sh: the STOPPED line before the last `start at` is old; a run that has started and not ended is running (4).
wd="$tmp/wait/docs/briefs/w"; mkdir -p "$wd" "$tmp/wait/state"
cat > "$wd/run.log" <<'EOL'
2026-11-24 22:00:00 start at aaaaaaa on m16
2026-11-24 22:10:00 STOPPED: PAUSED after wave 1
RESULT: STOPPED: PAUSED after wave 1
2026-11-24 22:20:00 start at bbbbbbb on m16
2026-11-24 22:20:05 start job1
EOL
printf 'job: w j\nexpected-min: 600\nreport: x\n' > "$wd/job1.md"
rcw=0; WAIT_STATE_DIR="$tmp/wait/state" bash "$loc/tools/wait-run.sh" "$wd" --max 2 > "$out" 2>&1 || rcw=$?
if [ "$rcw" = 4 ]; then r=0; else r=1; fi
report "wait-run.sh does not take the stop line of the run before the last start at for the current run (exit $rcw, want 4)" "$r"
printf '2026-11-24 22:30:00 STOPPED: PAUSED after wave 1\nRESULT: STOPPED: PAUSED after wave 1\n' >> "$wd/run.log"
rcw=0; WAIT_STATE_DIR="$tmp/wait/state" bash "$loc/tools/wait-run.sh" "$wd" --max 2 > "$out" 2>&1 || rcw=$?
if [ "$rcw" = 1 ]; then r=0; else r=1; fi
report "wait-run.sh reports the stop line the run itself logged (exit $rcw, want 1)" "$r"

if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
