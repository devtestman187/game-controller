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
nap=$(f stub-sleep); swt=$(f stub-worktree); [ -n "$swt" ] && echo "---- flash: job worktree $swt"
std=$(f stub-touch)
if [ "$(f stub-stdin)" = yes ]; then IFS= read -r line; echo "stdin:${line:-EOF}" >> "$STUB_STDIN_OUT"; fi
if [ -n "$nap" ]; then
  if [ -n "$std" ]; then for _ in $(seq "$nap"); do echo x > "$std/f"; sleep 1; done; else sleep "$nap"; fi
fi
wf=$(f stub-wait-for); if [ -n "$wf" ]; then for _ in $(seq 100); do [ -e "$wf" ] && break; sleep 0.1; done; fi
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
  "$loc"/tools/run-limits.sh "$loc"/tools/run-wave.sh "$loc"/tools/run-guard.sh "$loc"/tools/proc-lib.sh "$repo/tools/"
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
mkdir -p "$repo/src" && printf 'base\n' > "$repo/src/dirty.txt" && git -C "$repo" add -A && git -C "$repo" commit -q -m dirtybase || exit 2
printf 'allow: src/parked.txt · src/shared.txt · src/dirty.txt · %s/pk-report.md\nreport: %s/pk-report.md\nexpected-min: 20\nturns: 5\nstub-wait-for: src/shared.txt\nstub-write: src/parked.txt\nstub-rc: 1\n' "$batch" "$batch" > "$repo/$batch/pk.md"
printf 'allow: src/shared.txt · %s/sib-report.md\nreport: %s/sib-report.md\ncheck: format analyze\nexpected-min: 20\nstub-write: src/shared.txt\n' "$batch" "$batch" > "$repo/$batch/sib.md"
waves "pk sib"; row pk 8 60
printf 'edit\n' > "$repo/src/dirty.txt" # dirty after the briefs commit, as a person's edit would be
run_jobs
if [ "$rc" = 1 ] && logged "committed sib" && done_has sib && ! done_has pk && [ ! -e "$repo/src/parked.txt" ] &&
  git -C "$repo" ls-tree -r --name-only HEAD | grep -qx src/shared.txt && grep -qx edit "$repo/src/dirty.txt" &&
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


# 6b. tune4 T1, the stale waiter: a waiter launched before the restarted runner wrote its `start at` line must not
#     return the stop of the run before (PAUSED). Without --since that old stop is returned at once (exit 1: the bug).
wd2="$tmp/wait2/docs/briefs/w"; mkdir -p "$wd2" "$tmp/wait2/state"
printf '2026-11-24 22:00:00 start at aaaaaaa on m16\n2026-11-24 22:10:00 STOPPED: PAUSED after wave 1\nRESULT: STOPPED: PAUSED after wave 1\n' > "$wd2/run.log"
printf 'job: w j\nexpected-min: 600\nreport: x\n' > "$wd2/job1.md"
rcw=0; WAIT_STATE_DIR="$tmp/wait2/state" bash "$loc/tools/wait-run.sh" "$wd2" --max 2 > "$out" 2>&1 || rcw=$?
old_rc=$rcw
since=$(date +%s)
rcw=0; WAIT_STATE_DIR="$tmp/wait2/state" bash "$loc/tools/wait-run.sh" "$wd2" --max 2 --since "$since" > "$out" 2>&1 || rcw=$?
if [ "$old_rc" = 1 ] && [ "$rcw" = 4 ] && grep -q "waiting for the runner's new start at" "$out"; then r=0; else r=1; fi
report "a waiter with --since does not return the old stop before the restart's start at line (without it exit $old_rc; with it $rcw, want 4)" "$r"
printf '%s start at bbbbbbb on m16\n' "$(date '+%F %T')" >> "$wd2/run.log"
rcw=0; WAIT_STATE_DIR="$tmp/wait2/state" bash "$loc/tools/wait-run.sh" "$wd2" --max 2 --since "$since" > "$out" 2>&1 || rcw=$?
if [ "$rcw" = 4 ] && ! grep -q "PAUSED" "$out"; then r=0; else r=1; fi
report "after the new start at line the --since waiter follows the new run (exit $rcw, want 4, no old stop printed)" "$r"
rcw=0; WAIT_STATE_DIR="$tmp/wait2/state" WAIT_START_GRACE_S=1 bash "$loc/tools/wait-run.sh" "$wd" --max 5 --since "$(( $(date +%s) - 10 ))" > "$out" 2>&1 || rcw=$?
if [ "$rcw" = 5 ]; then r=0; else r=1; fi
report "a --since waiter with no newer start at line gives up with NO START (exit $rcw, want 5)" "$r"

# 7. tune4 T2, the hung-job guard: a job whose worktree and log show no change for RUN_JOB_IDLE_MIN minutes is killed and
#    logged "hung" (parked, the sibling is committed). A job that keeps writing files is not hung however long it runs.
fixture hung
mkdir -p "$tmp/wt-hung"
brief hj "stub-sleep: 27" "stub-worktree: $tmp/wt-hung"
brief sib
waves "hj sib"
export RUN_JOB_IDLE_MIN=3 RUN_IDLE_POLL_S=1
run_jobs
if [ "$rc" = 1 ] && logged "job hj hung: no file of its worktree or log changed for 3 min" && logged "committed sib" && ! done_has hj; then r=0; else r=1; fi
report "a job with no file change for RUN_JOB_IDLE_MIN is logged hung and parked; its sibling is committed (exit $rc)" "$r"
fixture busy
mkdir -p "$tmp/wt-busy"
brief bj "stub-sleep: 8" "stub-worktree: $tmp/wt-busy" "stub-touch: $tmp/wt-busy"
waves bj
run_jobs
if [ "$rc" = 0 ] && done_has bj && ! logged "hung"; then r=0; else r=1; fi
report "a job that keeps writing files for longer than RUN_JOB_IDLE_MIN is not hung (exit $rc)" "$r"
unset RUN_JOB_IDLE_MIN RUN_IDLE_POLL_S

# 8. tune4 T3, over-cap auto-apply: a job over its cap whose worker ended nonzero (result 1: the turn cap), whose own
#    checks are green and whose report has a Summary is applied ("over-cap applied"); a failing result 5 is still parked.
fixture overcap
brief oc "turns: 5" "stub-write: src/app.dart" "stub-rc: 1"
waves oc; row oc 8 60
run_jobs
if [ "$rc" = 0 ] && done_has oc && logged "over-cap applied: job oc used 8 turns, over its cap of 5" && logged "committed oc"; then r=0; else r=1; fi
report "an over-cap job (worker result 1) with green checks and a finished report is applied, not parked (exit $rc)" "$r"
fixture overcap5
brief oc5 "turns: 5" "stub-write: src/app.dart" "stub-rc: 5"
waves oc5; row oc5 8 60
run_jobs
if [ "$rc" = 1 ] && ! done_has oc5 && ! logged "over-cap applied"; then r=0; else r=1; fi
report "an over-cap job with worker result 5 (a failed check) is still parked (exit $rc)" "$r"
fixture overcapbad
brief ocb "turns: 5" "stub-write: src/app.dart" "stub-rc: 1"
waves ocb; row ocb 8 60
STUB_CONTENT=BROKEN run_jobs
if [ "$rc" = 1 ] && ! done_has ocb && ! logged "over-cap applied"; then r=0; else r=1; fi
report "an over-cap job with a failing runner check is parked even with a report (exit $rc)" "$r"

# 9. tune4 M2, phase lines: run.log names the phases (preflight is skipped here, worker, check, apply), each closing the last.
fixture phases
brief pj
waves pj
run_jobs
if grep -q "phase: worker" "$repo/$batch/run.log" && grep -q "phase: check (tests-first took " "$repo/$batch/run.log" &&
  grep -q "phase: apply (check took " "$repo/$batch/run.log"; then r=0; else r=1; fi
report "run.log carries phase lines: worker, tests-first, check (tests-first took ...), apply (check took ...)" "$r"

# 10. tune4 T5: a run review that wrote no REVIEW.md leaves a partial stub (a REVIEW.md always exists).
(
  B="$tmp/rev"; LOGS="$tmp/rev"; mkdir -p "$B"; WORK="$tmp/rev"
  note() { :; }; save() { echo "saved $*" >> "$tmp/rev/saves"; }; finding() { echo "finding $*" >> "$tmp/rev/saves"; }
  unchurn() { :; }; run_review() { return 1; }; outside_files() { :; }; CHURN_OUTSIDE=x
  . "$loc/tools/run-review.sh"
  run_review() { return 1; }
  final_review
) > "$out" 2>&1
if grep -q '^## Summary' "$tmp/rev/REVIEW.md" 2> /dev/null && grep -q 'partial' "$tmp/rev/REVIEW.md" && grep -q "stub" "$tmp/rev/saves"; then r=0; else r=1; fi
report "a run review with no REVIEW.md leaves a partial stub that is saved" "$r"

# 11. tune4 K1: the worker is started with </dev/null: a worker that reads stdin sees EOF, not the runner's input.
fixture stdin
printf 'typed\n' > "$tmp/typed"
export STUB_STDIN_OUT="$tmp/stdin-out"; : > "$STUB_STDIN_OUT"
brief sj "stub-stdin: yes"
waves sj
run_jobs < "$tmp/typed"
if [ "$rc" = 0 ] && grep -q "^stdin:EOF" "$STUB_STDIN_OUT"; then r=0; else r=1; fi
report "the runner starts the worker with </dev/null (it read: $(cat "$STUB_STDIN_OUT"))" "$r"
if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
