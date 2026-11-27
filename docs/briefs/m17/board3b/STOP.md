STOP 2026-11-27 02:21:13 docs/briefs/m17/board3b
cause: checks failed twice on the combined tree after g3d2b
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 498s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-021140/tools.log
        FAIL  tools/tests/run-stops-test.sh (320s)
          FAIL a job with no file change for RUN_JOB_IDLE_MIN is logged hung and parked; its sibling is committed (exit 1)
        FAIL  tools/tests/run-wave-test.sh (63s)
          FAIL one wave's job past its limit is parked while its two siblings are committed, then the run stops naming it (30s)
          FAIL a restart runs the parked job only and skips the two committed ones (exit 0)
        FAIL  tools/tests/run-wire2-test.sh (72s)
          FAIL a STOP-file stop kills the running wave review at once, with no report committed (exit 1)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:50:50 worker: claude
  2026-11-27 01:50:51 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:50:56 phase: preflight
  2026-11-27 01:51:03 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:51:34 phase: worker (preflight took 38s)
  2026-11-27 01:51:34 skip g3d1s (already done)
  2026-11-27 01:51:55 phase: worker (worker took 21s)
  2026-11-27 01:51:56 WARN: g3d2 was committed by hand (7c25a187); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-27 01:52:01 tests-first ok: tools/sim/night_sim_test.dart fails on the old code
  2026-11-27 01:52:03 hand-fixed g3d2: tests-first proof and worker review done (marked in done.txt)
  2026-11-27 01:52:03 skip g3d2 (already done)
  2026-11-27 01:52:25 phase: worker (worker took 30s)
  2026-11-27 01:54:54 start g3d2b
  2026-11-27 02:01:57 g3d2b finished: result 0 (42 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 64/1914039/78095/52299
  2026-11-27 02:01:57 phase: tests-first (worker took 572s)
  2026-11-27 02:02:02 tests-first ok: tools/sim/sim_report_test.dart fails on the old code
  2026-11-27 02:02:31 phase: check (tests-first took 34s)
  2026-11-27 02:02:37 combined check: skips protocol connection metrics kit look arena puzzle host phone tv (no job's change reaches them)
  2026-11-27 02:11:34 checks failed; fetching packages and trying once more
  2026-11-27 02:21:13 STOPPED: checks failed twice on the combined tree after g3d2b
