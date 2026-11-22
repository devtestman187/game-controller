# identity1 wave 1 report (driver, Nov 21)

Result: STOPPED (check-failed) at the wave's combined check. Nothing of wave 1 is committed (only the runner's own STOP.md/run.log commit 2dde4ebc). Wave 1 review did not start. Waves 2-3 not started. Wave 1 work sits uncommitted in the worktree (i1a, i1c) and in a kept job worktree (i1b).

## Jobs (turns / minutes from run.log)
| job | turns | min | worker result |
|---|---|---|---|
| i1a | 66 | 6 | result 5: flash "CHECKS FAILED", changes applied to tree (uncommitted) |
| i1b | 57 | 8 | result 4 (files outside allow: only generated site/shots/*.png, auto-dropped); "changes NOT applied", worktree kept at /e/AI/game-controller-m16-jobs/flash-20261121-213529-304619; so i1b code is NOT in the main tree |
| i1c | 61 | 6 | result 0, applied (uncommitted) |
Tests-first proofs: ok for identity_wire_test, toy_character_name_test; identity_reservation_test exempt per brief.

## The stop
Runner combined check failed twice (22:30:45 retry, 23:17:16 STOPPED). STOP.md (summary): class check-failed; analyze errors `non_exhaustive_switch_statement` at packages/connection/lib/src/client_messages.dart:38 and host_connection.dart:188 (new `PlayersMessage` from i1a is not handled); this breaks compile of arena, connection, host, kit, phone, puzzle, tv suites (hundreds of load errors). Cause: brief defect. i1a's `allow:` lists protocol/toy_look/docs only; the sealed Message switches in `connection` (and codec.dart, noted in i1a-report question 1) were not in any wave-1 job's allow. The i1a worker saw "CHECKS FAILED" itself (result 5) but the runner carried on. Fix needs the two switches (+ codec.dart registration) handled: add a `PlayersMessage` case (ignore) in connection, which is owner of neither i1a nor i1c; either widen i1a's allow (connection/client_messages.dart, host_connection.dart, codec.dart) or hand-fix, then rerun i1a. Not done: owner usage pause point / design of fix.
Second independent check failure: `tools` suite inside the combined check: tools/tests/run-wire-test.sh TIMEOUT at 120 s in both runner checks and in my pre-run `check.sh tools` (6 of 7 pass). Run alone it passes in 114 s. So tools check is flaky/slow on this PC (limit 120 s); it will fail the runner's check even after the connection fix. Needs a decision (raise the per-script limit or speed the test).

## Pre-run
`bash tools/check.sh tools`: FAIL (run-wire-test.sh TIMEOUT 121 s; others pass; alone passes 114 s). Dry-run OK. Wave selection: runner has no wave option; I temporarily replaced waves.txt with "i1a i1b i1c" and restored it via git checkout after the stop (waves 1-3 intact, git-clean).

## Watch list
- Hand-fixes/hand-merges: none.
- Workers used tools/mine.sh: not determinable from flash logs (no tool-call lines; reports do not mention it). Not confirmed.
- Churn auto-handled: yes (site/shots PNGs dropped for i1b). tv_test_app generated plugin files are dirty in the tree (known churn, unstaged).
- STOP.md written and read first: yes.
- Lock / RUN_MAX_MIN: no lock or RUN_MAX_MIN messages seen; the final combined check ran 41 min before the retry (21:49-22:30) and 46 min for the retry (22:30-23:17), far above the ~7 min norm, and RUN_MAX_MIN did not trigger. The STOP file I touched at 22:33 was not honoured during the check (checked only between steps); runner stopped on its own at 23:17.
- docs/worker-extract.md appended: no diff in the tree and no trace in flash logs; not confirmed.
- wait-run.sh: OVERRUN repeated (exit 2 immediately each call) once i1c passed 1.5x its estimate (B.1a); also reported "running: preflight (no job started yet) for 23 min" during the combined check. I used 5 wait-run.sh calls (2 useful, rest instant), then switched to my own 30 s x 5 loops (about 40 calls).
- Usage per job (flash-usage.tsv): i1a 66 turns, i1c 61, i1b 57; turns all within limits.
- Driver wall clock: 21:28 to 23:18 (about 1 h 50 min), of which pre-check 4 min, jobs 14 min, runner check 88 min.

## State left
Branch m16 tip 2dde4ebc (runner commit). Dirty: i1a and i1c edits uncommitted, new files untracked (identity.dart, host_character_reservation.dart, tests, reports), tv_test_app plugin churn. i1b output only in the kept job worktree. Nothing pushed, tagged, built. git user.email is the devtestman187 noreply.
Repair options: (1) widen i1a allow to the three connection files, rerun; (2) hand-add `PlayersMessage` cases (HAND-FIX i1a in run.log) then restart; and fix/raise the run-wire-test timeout first.
