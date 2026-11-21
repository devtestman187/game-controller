# p2-wire report: the runner writes STOP.md, auto-applies churn, has a lock and a time limit

## Summary

- **STOP.md at every stop.** `stop()`, `check_stop()` and the brief-lint exit write
  `<batch>/STOP.md` with `tools/run-stop.sh` before they commit; `save_stop` commits it beside
  `run.log`; `clear_last_stop` removes the last stop's STOP.md at the next start and commits the
  removal. A failing `run-stop.sh` is a finding, never a different exit. The failed-jobs stop
  passes the first failed job's log, so STOP.md quotes its outside block.
- **Churn, one source.** `run-jobs.sh` sources `tools/churn.sh` for `CHURN_OUTSIDE`
  (`CHURN_REGEX`) and its unchurn paths (`CHURN_PATHS`); the inline copies are gone.
  `CHURN_REGEX` gained `([^/]+/)*[^/]+-results\.json`, the test-written `s7-results.json` that
  caused f1, f2 and f3's result-4 stops in phonehost1's run.log, so such a job is applied and
  logged, never stopped.
- **Lock.** `$WORK/lock` holds the pid: a live one makes a second runner exit 2 with
  `RESULT: refused, a run is active (pid N)`, a stale one is replaced with a log line, and
  `trap ... EXIT INT TERM` removes it.
- **Time limit.** `RUN_MAX_MIN` (360) with `RUN_START_S`; `check_stop` asks `time_check` first,
  so every stop point and each 5 s poll mid-wave enforces it: past it, `STOPPED: TIMEOUT`, exit 1.
- **Size.** `run-jobs.sh` 336 lines (limit 340); the new helpers live in `run-steps.sh` (175).
  `tools/run-stop.sh` is outside this job's allow: and is called, not changed.

**Tests:** `tools/tests/run-wire-test.sh` is new, 10 cases, 44 s; `run-jobs-split-test.sh` now
copies `churn.sh` and checks 340 lines. I saw `PASS tools` with both scripts (44 s, 6 s); the
per-case lines are only printed on a failure.

**Decisions (one line each, why):**

- The new logic went into `tools/run-steps.sh`, not into `tools/run-jobs.sh` or
  `tools/run-stop.sh`: the brief caps the runner at 340 lines and `run-stop.sh` is outside
  this job's allow:.
- `stop()` kills its own child processes (once, for every stop) because `time_check` fires
  mid-wave; the stop-file path killed them in `check_stop` before, with the same result.
- `save()` now stages with `git add -A -f`, so `clear_last_stop` commits the STOP.md deletion;
  every caller still names its own paths.
- `*-results.json` is a pattern, not the one file `s7-results.json`: any test that writes its
  numbers beside its report gets the same treatment. A job that lists the file in `allow:` still
  commits it (it never reaches the outside list, so it is never dropped).
- The failing-job stop passes the first failed job's log as the optional flash-log argument;
  other stops pass the cause alone.

## The test cases (what each one pins)

1. a failed check: `STOPPED: checks failed twice ...`, STOP.md has the cause, HEAD has STOP.md, exit 1.
2. the STOP file (made by the preflight stub): `STOPPED: stop file`, STOP.md names it, committed, exit 1.
3. the brief lint (bad `report:` line): `STOPPED: brief lint`, STOP.md names the report line, committed, exit 1.
4. a failing `run-stop.sh`: no STOP.md, exit stays 1, the finding says "STOP.md was not written", run.log committed.
5. result 4 with only `site/shots/join.png` and `docs/briefs/fix/runjob-results.json` outside: dropped, job committed, no STOPPED, exit 0.
6. a live pid in `$WORK/lock`: exit 2 and the last line is the `RESULT: refused, a run is active (pid N)`, nothing logged.
7. a stale lock (pid 2147483): "replaced a stale lock (pid 2147483 is gone)", the run goes on to its own stop, the trap removed the lock.
8. `RUN_MAX_MIN=0`: `STOPPED: TIMEOUT`, STOP.md with `RUN_MAX_MIN=0` in the cause, committed, exit 1.
9. a committed STOP.md from an earlier stop: removed at the start, the removal committed, the run's own STOP.md left, exit 1.
10. `--dry-run` with `RUN_MAX_MIN=0`: exactly the three plan lines, no lock, no STOP.md, no flash marker, exit 0.

**Values I computed for the expectations:** the dropped-churn line is exactly
`runjob: dropped generated churn outside its list: site/shots/join.png docs/briefs/fix/runjob-results.json`;
the refusal line is exactly `RESULT: refused, a run is active (pid <the sleep pid>)`; the stale
line is `replaced a stale lock (pid 2147483 is gone)`; the plan is `wave 1:` / `  runjob: run` /
`then: the run's review -> docs/briefs/fix/REVIEW.md`; sizes 336 / 175 / 72 and 10 / 8 cases.

## Self-check (docs/review-rules.md part A)

This job is shell tooling with no app state, so items 1-3 and 6 are answered by what stands in
for them rather than by a screen test:

1. **Every host setup:** no host is involved; the runner refuses/commits only files, and the
   tests put the briefs folder inside the repo so git sees the paths (case 10's plan proves the
   dry run reads them relative to the repo root).
2. **When kept state starts and ends:** the lock starts at `lock_take` (after the dry run) and
   ends with the EXIT/INT/TERM trap (case 7 asserts the lock file is gone); STOP.md starts at a
   stop and ends at the next start (case 9 asserts both the log line and the removal commit);
   `RUN_START_S` is set once, before the lock is taken.
3. **How it combines:** the time limit and the STOP file are checked in the same `check_stop`,
   so a stop file and a timeout can't fight over the exit (cases 2 and 8); a stop still flushes
   and kills the background review chain through `stop` as before.
4. **Stay in the job's folder and inside allow:** only the seven allowed paths changed (runner,
   steps, churn, the two tests, dev-tools, this report), and new runner logic sits in
   run-steps.sh and churn.sh, both in allow:.
5. **Stop rather than overstep:** `tools/run-stop.sh` is called, never edited (it is not in
   allow:), and `tools/run-jobs.sh` stayed at 336 lines rather than grow past 340.
6. **Every look:** no look-sized widget is touched; the only text is STOP.md and the run.log, and
   run-stop.sh fits STOP.md to 40 lines (its own test covers that).

## Questions and suggestions (not acted on)

1. `apply_safe` still repeats a few churn paths as inline exclude globs (`site/shots/**`,
   `**/run-base*`, ...). They could come from `churn.sh` too, but they are a safety net for the
   patch step, so I left them.
2. The mid-wave poll sleeps 5 s, so every job shorter than that costs the run one poll, and the
   wire test pays it twice (10 s of its 44 s). A 1 s poll would make STOP and RUN_MAX_MIN react
   sooner; I did not change behaviour the brief did not ask for.
3. s6b2's result-4 stop (site/shots churn only, already in the list) is not explained by the old
   logs; the remaining suspect is `apply_safe`'s `git apply --3way` step, which still returns 1
   (a stop) when the patch cannot be applied. Worth a look if it happens again.

## Hand-over

`tools/check.sh format` and `tools/check.sh tools` pass on this tree. Nothing was run against a
device, an emulator or a real worker call: the wire test stubs `flash.sh`, `check.sh`,
`review.sh`, `commit-job.sh` and `run-stop.sh`.

## Commit message

M16 process2: the runner writes STOP.md, locks and times itself

Every stop (a FAIL, a failed job, STOP, the brief lint) writes and commits
<batch>/STOP.md; the next start removes and commits it, and a failing
run-stop.sh is a finding, not a different exit.
tools/churn.sh is now the one churn list and drops a test-written
*-results.json too, so a result-4 job whose only outside files are churn is
applied instead of stopped.
The work folder's lock refuses a second runner (exit 2), and past RUN_MAX_MIN
(360 min) the runner stops with STOPPED: TIMEOUT.

## Status row

M16 process2 p2-wire: done (STOP.md at every stop, churn one source with *-results.json auto-applied, per-batch lock, RUN_MAX_MIN timeout, 10-case run-wire test); open: apply_safe's patch step is still the stop for a churn-only result 4 with no patchable change (finding 3).

## Delete

- none
