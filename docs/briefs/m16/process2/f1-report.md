# f1 — runner lock trap, finding commit, churn-only result 4

## Summary

Three fixes in `tools/run-steps.sh`, five cases in `tools/tests/run-wire-test.sh` (14 cases now).

1. **The lock trap** (`lock_take`): the old `trap 'rm -f "$WORK/lock"' EXIT INT TERM` removed the lock on
   INT/TERM and left the run going. Now `lock_remove` is the EXIT trap only and takes the lock away only when
   `$(cat "$WORK/lock")` is `$$`; `INT` exits 130 and `TERM` exits 143, each switching further signals off
   first (`trap "" INT TERM`), as `tools/selftest.sh:83-84` and `tools/mine.sh:84-85` do. The traps go in
   *before* the lock is written, so a signal in the window between the two cannot leave the lock behind.
2. **The finding at a stop** (`save_stop`): `$B/run-findings.md` is committed with `run.log` and `STOP.md` when
   it exists, so the "STOP.md was not written" finding (written by `write_stop` when `tools/run-stop.sh` fails)
   is no longer left uncommitted.
3. **A churn-only result 4** (`apply_safe`): when every outside file is generated churn and the patch is empty
   or `git apply --3way` fails, the job's own `allow:`/`report:` paths are copied from the kept worktree by a new
   `copy_paths` (files, folders, and a path the job deleted), the churn is left behind, and the runner logs it.
   A job with any always-fine or other outside file takes the old patch road unchanged.

Tests, all run in this job:

- `tools/check.sh --verbose tools` (the shell self-tests, `tools/check.sh tools`): 7/7 scripts pass, 185 s;
  `run-wire-test.sh` alone 14/14 cases pass in 75 s.
- The same suite on the **old** `tools/run-steps.sh` (reverted by hand for one run, then restored): the five new
  or extended cases fail and the other nine pass, 110 s — the proof the brief's "must fail on the code as it was"
  asks for.
- `tools/check.sh format`: PASS. `tools/mine.sh`: `RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed,
  0 package(s) tested` (it reverted 3 generated churn files).

Decisions:

- The fallback is unconditional for an all-churn result 4: I could not reproduce the exact s6b2 cause (its flash
  log is no longer in the batch folder), so both shapes the brief names — an empty patch and a patch that does not
  apply — are tested (cases 6 and 7). The copy never touches a file outside the job's own list.
- The `allow:`/`report:` list is now deduplicated (a brief usually names its report in both lines), so the diff and
  the new log line list each path once. No behaviour change on its own.
- The five tests live in the brief-named `tools/tests/run-wire-test.sh` rather than in a new file; the runner's
  tests-first proof only inspects `*_test.dart`, so the old-code run above is the proof instead.
- The runner is now started in the test with `set -m`: a background bash otherwise inherits INT ignored and no INT
  trap can ever run (this cost the first failing run 60 s a case).

## Test values computed for the expectations

- churn drop note (cases 5, 6, 7): `runjob: dropped generated churn outside its list: site/shots/join.png`
  and, with the results file, `... site/shots/join.png docs/briefs/fix/runjob-results.json`.
- copied paths (case 6): `copied its own paths from the kept worktree: src/app.dart docs/briefs/fix/runjob-report.md`
  (two entries despite three `allow:`/`report:` mentions, from the dedup).
- exit codes (cases 10, 11): 143 on TERM, 130 on INT; the lock is gone after TERM and still holds the other pid's
  number after INT.

## Self-check (docs/review-rules.md part A)

1. Every host setup: not applicable — this job touches runner tooling, no host, app or protocol state. The runner
   side of a job's life is covered by run-wire cases 1-14 (a stop, a stop file, a lint stop, a result 4, two
   runners, a signal).
2. Kept state: the lock starts at `lock_take` and ends at the EXIT trap; cases 10 and 11 show a signal ending it
   and case 9 shows a stale one replaced; when nothing is going on there is no lock (`[ ! -f "$work/lock" ]` in
   cases 9, 10, 14).
3. New state combined with what it can meet: the lock meets a second runner (case 8, exit 2) and a stale lock
   (case 9); the finding meets a failed `run-stop.sh` at a stop (case 4); the fallback meets only generated churn
   (cases 5-7) and refuses any other outside file (unchanged code path, the `else return 1`).
4. Stayed in the job's folder and inside `allow:`: only the three allowed files are modified.
5. Stop rather than overstep: nothing had to stop; the only thing not reproduced is the s6b2 cause itself (above).
6. Every look: not applicable — no widget, layout or look is touched.

## Hand-over

The runner now ends on INT/TERM instead of running on with its lock gone, a stop's finding is committed, and an
all-churn result-4 job is rescued by copying its own paths instead of stopping the batch. `run-wire-test.sh` takes
75 s of `tools/selftest.sh`'s 120 s per-script limit (the old code's run took 110 s), so the next cases added
there will need `SELFTEST_TIMEOUT` raised.

## Questions and suggestions

1. Reproducing the s6b2 failure exactly would let the fallback be narrower (only when the patch is empty, say);
   today it also runs for a patch that fails to apply. Keeping the flash log of a stopped job somewhere
   long-lived (`run.log` names `$LOGS/flash-<job>.log`) would make the next such case diagnosable.
2. A folder in `allow:` is copied whole by `copy_paths`, unchanged files included. Narrowing it to the paths
   `git status` reports in the worktree would be faster and would not carry a generated file that sits inside an
   allowed folder.
3. The INT case needs `set -m` in the test; any future test that traps INT in a background script needs the same.

## Commit message

runner: end the run on a signal, keep findings, rescue churn-only jobs

The lock trap removed the lock on INT/TERM and the run went on; INT now exits 130
and TERM 143 with further signals off, and the exit trap removes the lock only
when it holds this run's pid. save_stop commits run-findings.md, so the
"STOP.md was not written" finding survives a stop. apply_safe copies a job's
allow:/report: paths from the kept worktree when its outside files are all
generated churn and the patch is empty or does not apply, which was the s6b2
stop. run-wire-test.sh: five cases added or extended (14 in all), and all of
them fail on the old run-steps.sh.

## Status row

f1 done: signals end the runner (130/143) with only its own lock removed, a stop commits run-findings.md, and an all-churn result-4 job is copied from its kept worktree; run-wire 14/14 and the tools suite green (185 s); open: the s6b2 cause itself is not reproduced (the fallback is unconditional for all-churn jobs) and no dart suite ran (pub: no).

## Delete

- none
