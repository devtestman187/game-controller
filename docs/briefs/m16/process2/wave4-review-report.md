# wave4 review report: p2-wire

## Summary

`small fixes` — 0 must, 5 should, 4 could.

- **should** `tools/run-jobs.sh:139` — `stop` now kills the background review chain before `flush_reviews`, where the old `stop` waited for it, so any stop other than the STOP file loses a wave review that is still running (the report's decision calls that "the same result").
- **should** `tools/run-steps.sh:31` — a result-4 job whose only outside files are churn still stops when `git apply --3way` of the patch fails (s6b2, `docs/briefs/m16/phonehost2/run.log:93`), so the brief's "applied, never a stop" is not guaranteed; the job re-states it as an open question instead of a gap.
- **should** `tools/run-steps.sh:174` — the `EXIT INT TERM` trap deletes the lock but does not exit on INT/TERM, unlike `tools/mine.sh:84-85` and `tools/wait-run.sh:240-241`, so an interrupted runner keeps running without its lock.

## Findings

- **should** tools/run-jobs.sh:139 `stop` kills its own children before `flush_reviews`, so an in-flight wave review (started by `start_reviews`) is killed and its report is never committed at any stop except the STOP-file one, whose kill was in `check_stop` before → keep the old `wait` (or `flush_reviews wait`) for stops that are not `time_check`, and kill only there, or log a finding naming the review lost.
- **should** tools/run-steps.sh:31 `apply_safe` returns 1 when `git apply --3way` fails even though every outside file was churn, which is exactly the stop s6b2 took (docs/briefs/m16/phonehost2/run.log:93 and :99, all-generic `site/shots` churn) → fall back to copying the brief's allow:/report: paths out of the kept worktree when the patch is empty or fails, so a churn-only result 4 is applied as p2-wire item 2 promises.
- **should** tools/run-steps.sh:174 `trap 'rm -f "$WORK/lock"' EXIT INT TERM` removes the lock on INT/TERM but does not end the run, and it deletes the file without checking it holds `$$`, both of which `tools/mine.sh:79-85` and `tools/wait-run.sh:68-70,240-241` avoid → trap EXIT only for the removal plus `trap 'rm -f "$WORK/lock"; exit 130' INT` and `... exit 143' TERM`, and remove it only when `$(cat "$WORK/lock")` is `$$`.
- **should** tools/run-steps.sh:155 the finding "STOP.md was not written" is written to `$B/run-findings.md`, but `save_stop` (tools/run-steps.sh:131) commits only `run.log` and `STOP.md`, so the run ends with that finding uncommitted and a fresh clone never sees it (test 4 checks the working file only) → add `$B/run-findings.md` to `save_stop`'s paths when it exists.
- **should** tools/tests/run-jobs-split-test.sh:121 the split test's runner ceiling was raised from `-le 330` to `-le 340` to fit this job, which loosens p2-split's delivered check (docs/briefs/m16/process2/p2-split.md:9 says "at or under 330 lines") → keep 330 and put the change in a new ceiling only if the owner agrees, or say in the test's comment that the wire brief superseded 330.
- **could** tools/churn.sh:3 the header still says "tools/mine.sh is the caller" and tools/churn.sh:17 still says "the folders and files tools/run-jobs.sh calls CHURN", though the runner now sources the file and no `CHURN` array exists anywhere → name both callers and the current variable names (`CHURN_PATHS`, `CHURN_REGEX`).
- **could** docs/flash-framework.md:56 still says the design PNGs "are also in the runner's `CHURN` list", which this job removed (the list is now `CHURN_PATHS` in tools/churn.sh); the file is outside the job's allow:, so it fell through → one phrase to "the churn list in tools/churn.sh" in a follow-up doc job.
- **could** tools/run-steps.sh:29 `apply_safe` still repeats four churn paths as inline exclude globs (`tv_test_app/windows/flutter/**`, `site/shots/**`, `**/run-base*`, `docs/briefs/**/run-*.patch`), a third copy of the list the brief asked to keep in one source (its own open question 1) → build the excludes from `CHURN_PATHS`/`CHURN_REGEX`, or state in the code why they must differ.
- **could** tools/run-jobs.sh:323 the run's final review is a foreground `tools/flash.sh` call with no `time_check` during it, so a stuck final review keeps the runner past `RUN_MAX_MIN` with no `STOPPED: TIMEOUT`, which is the "abnormally long time" case the owner named → run it in the background under the same 5 s `check_stop` poll as the jobs, or check the clock around it and stop.

## Decisions to confirm

- `save()` now stages with `git add -A -f -- "$@"` (tools/run-jobs.sh:151) so `clear_last_stop` can commit one deletion; every caller inherits deletion staging for the paths it names — confirm no caller depends on a deletion staying unstaged.
- `([^/]+/)*[^/]+-results\.json` (tools/churn.sh:29) is a pattern, not `s7-results.json`: any `X-results.json` a job writes outside its allow: is silently dropped, test fixtures included; only an allow: listing keeps it.
- The runner's time limit counts from its own start (`RUN_START_S`, tools/run-jobs.sh:111), so a batch that stops and is restarted never reaches `RUN_MAX_MIN`; "the run" in the owner's decision could mean the batch (count from the first `start at` line of `run.log`) instead.
- `stop` kills its own children for *every* stop, not only the time limit and the STOP file (see finding 1); the report lists it as a decision, so confirm the loss of an in-flight review is acceptable.

## Could not check

- Could not run either test script (the session's Bash approval refuses `bash <script>`, as p2-split's report also noted), so the "44 s / 6 s PASS tools" lines are the report's claim; the runner's own evidence is that p2-wire was committed (docs/briefs/m16/process2/run.log:57), which needs `tools/check.sh` green.
- Why `apply_safe` failed for s6b2: its kept worktree and `flash-s6b2.log` are gone, so finding 2 rests on run.log:93/:99/:100 only.
- The 360-minute limit cannot be exercised except as `RUN_MAX_MIN=0`; the tests never show a run stopping at a non-zero limit.

## Commit message

docs: wave4 review of p2-wire (small fixes)

Reviewed 573e61a2 against its brief, the guidelines and the review rules:
STOP.md at every stop, churn one source, the lock and RUN_MAX_MIN are in
place and covered by the 10-case wire test.
Five shoulds: a stop kills a running wave review, a churn-only result 4
still stops when the patch fails, the INT/TERM trap removes the lock
without exiting, the STOP-failure finding is not committed, and the split
test's 330-line ceiling became 340.

## Status row

M16 process2 p2-wire: reviewed in wave4 (0 must, 5 should, 4 could); open: the review-chain kill at a stop, the INT/TERM lock trap, the uncommitted STOP.md finding, the raised split-test ceiling, and apply_safe's patch stop for a churn-only result 4.

## Delete

- none
