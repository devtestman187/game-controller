# Rehearsal result (Nov 22, driver): all checks passed

Setup: throwaway worktree E:/AI/game-controller-m16-rehearsal on branch rehearsal (stub tools/check.sh, tools/fail-analyze.sh; both deleted with it), FLASH_CMD=tools/fake-flash.sh, scratch usage log, PREFLIGHT_SKIP=1, RUN_POLL_S=2. Two briefs r1 r2 (expected-min 1), one wave. No dummy files remain in m16; the worktree and branch are removed; no process left.

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Normal job finish, DONE, RESULT line, wait-run exit 0 | PASS | `r1 finished: result 0 (10 turns, 0 min)`, `committed r1`, `committed r2`, `DONE: every job is committed`, `RESULT: DONE: 2 jobs, 0 min`; wait-run EXIT=0 |
| 2 | Per-step job limit stop, STOP.md written and read first | PASS | run.log `STOPPED: job r1 passed its limit (2 min, estimate 1)` (limit 1 x 250% = 150 s; fake sleep 210 s); STOP.md cause line the same; `RESULT: STOPPED: job r1 passed its limit ...` |
| 3 | wait-run OVERRUN once per job, later calls keep waiting | PASS (cosmetic notes) | waiter call: `RESULT: OVERRUN: r1 has run 1 min, expected ~1` EXIT=2; next call reports r2 (its own first OVERRUN), never r1 again; then EXIT=1 STOPPED. The text "1 min, expected ~1 (1.5 x is 1 min)" is rounded to whole minutes; the stop text says "2 min" for 150 s |
| 4 | "checking" state | PASS | waiter: `RESULT: running: checking: the combined check for 2 min` EXIT=4 (stub check sleeping 300 s) |
| 5 | STOP file honoured during the check | PASS | file touched 07:36:18 (during a 300 s stub check), run.log `07:36:20 STOPPED: stop file` (2 s, RUN_POLL_S=2), `RESULT: STOPPED: stop file`; no check processes left |
| 6 | Base-compile preflight refusal | PASS | `STOPPED: the base does not compile: error - lib/fake.dart:1:1 ... fake_error (log ...run-base-check.log); no job of wave 1 was started`; STOP.md cause the same; no `start r1` line; wait-run EXIT=1 |
| 7 | RESULT line on every exit | PASS | DONE, limit stop, stop-file stop and base refusal all end run.log with a `RESULT:` line |
| - | Not rehearsed | | turn-cap stop (covered by run-limits-wire-test), RUN_MAX_MIN backstop TIMEOUT, resume row 7 (the real process3 run showed `resume p3d/p3e (applied by hand, not committed yet)` on every restart: correct, those jobs' files were in the tree uncommitted; the line reflects that, it is not the resume bug) |

## Haiku waiter
Worked, 3 of 4 runs (runs 1, 2, 3; run 4 was instant). Tool calls: run 1 = 1, run 2 = 1 (returned at the OVERRUN, exit 2; the follow-up calls were mine), run 3 = 2. Total 4 Bash calls by waiters; each waiter ended on a non-4 exit, as briefed. Each waiter's own context cost about 60k tokens (mostly its fixed prompt), so for runs under 3 minutes a plain wait-run call is cheaper; the waiter pays off for waits over about 10 minutes.

## Evidence copies
Runner logs of runs 1-4 were copied to a scratch folder and quoted above; they lived in the removed worktree.
