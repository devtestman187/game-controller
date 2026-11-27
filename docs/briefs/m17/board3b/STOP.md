STOP 2026-11-27 01:50:12 docs/briefs/m17/board3b
cause: checks failed twice on the combined tree after g3d2
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 501s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-014115/tools.log
        FAIL  tools/tests/run-stops-test.sh (321s)
          FAIL a job with no file change for RUN_JOB_IDLE_MIN is logged hung and parked; its sibling is committed (exit 1)
        FAIL  tools/tests/run-wave-test.sh (63s)
          FAIL one wave's job past its limit is parked while its two siblings are committed, then the run stops naming it (30s)
          FAIL a restart runs the parked job only and skips the two committed ones (exit 0)
        FAIL  tools/tests/run-wire2-test.sh (72s)
          FAIL a STOP-file stop kills the running wave review at once, with no report committed (exit 1)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:24:45 RUN_MAX_MIN=88 min (computed backstop of the jobs still to do)
  2026-11-27 01:24:45 start at 9ca5cccc on board-line
  2026-11-27 01:24:45 worker: claude
  2026-11-27 01:24:46 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:24:54 phase: preflight
  2026-11-27 01:25:00 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:25:16 phase: worker (preflight took 22s)
  2026-11-27 01:25:17 WARN: g3d1s was committed by hand (75053303); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-27 01:25:22 tests-first ok: tools/sim/bots_test.dart fails on the old code
  2026-11-27 01:25:23 hand-fixed g3d1s: tests-first proof and worker review done (marked in done.txt)
  2026-11-27 01:25:23 skip g3d1s (already done)
  2026-11-27 01:25:40 phase: worker (worker took 24s)
  2026-11-27 01:26:52 start g3d2
  2026-11-27 01:31:27 g3d2 finished: result 0 (18 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 28/682350/72168/51546
  2026-11-27 01:31:27 phase: tests-first (worker took 347s)
  2026-11-27 01:31:32 tests-first ok: tools/sim/night_sim_test.dart fails on the old code
  2026-11-27 01:32:05 phase: check (tests-first took 38s)
  2026-11-27 01:32:09 combined check: skips protocol connection metrics kit look arena puzzle host phone tv (no job's change reaches them)
  2026-11-27 01:41:12 checks failed; fetching packages and trying once more
  2026-11-27 01:50:12 STOPPED: checks failed twice on the combined tree after g3d2
