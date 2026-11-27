STOP 2026-11-27 02:51:37 docs/briefs/m17/board3b
cause: checks failed twice on the combined tree after g3g
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 497s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-024302/tools.log
        FAIL  tools/tests/run-stops-test.sh (319s)
          FAIL a job with no file change for RUN_JOB_IDLE_MIN is logged hung and parked; its sibling is committed (exit 1)
        FAIL  tools/tests/run-wave-test.sh (62s)
          FAIL one wave's job past its limit is parked while its two siblings are committed, then the run stops naming it (30s)
          FAIL a restart runs the parked job only and skips the two committed ones (exit 0)
        FAIL  tools/tests/run-wire2-test.sh (72s)
          FAIL a STOP-file stop kills the running wave review at once, with no report committed (exit 1)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 02:23:24 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 02:23:26 phase: preflight
  2026-11-27 02:23:32 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 02:23:47 phase: worker (preflight took 21s)
  2026-11-27 02:23:48 skip g3d1s (already done)
  2026-11-27 02:24:03 phase: worker (worker took 16s)
  2026-11-27 02:24:04 skip g3d2 (already done)
  2026-11-27 02:24:19 phase: worker (worker took 16s)
  2026-11-27 02:24:20 WARN: g3d2b was committed by hand (acae9fc2); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-27 02:24:25 tests-first ok: tools/sim/sim_report_test.dart fails on the old code
  2026-11-27 02:24:26 hand-fixed g3d2b: tests-first proof and worker review done (marked in done.txt)
  2026-11-27 02:24:26 skip g3d2b (already done)
  2026-11-27 02:24:43 phase: worker (worker took 24s)
  2026-11-27 02:27:47 start g3g
  2026-11-27 02:33:20 g3g finished: result 0 (30 turns, 5 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 46/800466/44409/23944
  2026-11-27 02:33:21 phase: tests-first (worker took 518s)
  2026-11-27 02:33:26 phase: check (tests-first took 5s)
  2026-11-27 02:33:29 combined check: skips protocol connection metrics kit look arena puzzle host phone tv (no job's change reaches them)
  2026-11-27 02:42:59 checks failed; fetching packages and trying once more
  2026-11-27 02:51:37 STOPPED: checks failed twice on the combined tree after g3g
