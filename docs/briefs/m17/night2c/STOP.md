STOP 2026-11-27 11:17:56 docs/briefs/m17/night2c
cause: checks failed twice on the combined tree after t2 d1 v2
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 453s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-110210/tools.log
        FAIL  tools/tests/tv-word-test.sh (2s)
          FAIL the real repo: exit
          FAIL the real repo: no hit lines
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 10:20:54 removed the last stop's STOP.md
  2026-11-27 10:21:15 phase: preflight
  2026-11-27 10:21:22 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 10:21:37 phase: worker (preflight took 22s)
  2026-11-27 10:21:38 skip v1a (already done)
  2026-11-27 10:21:38 skip c1 (already done)
  2026-11-27 10:21:39 skip t1 (already done)
  2026-11-27 10:21:54 phase: worker (worker took 17s)
  2026-11-27 10:21:55 start v2
  2026-11-27 10:22:21 start t2
  2026-11-27 10:26:52 start d1
  2026-11-27 10:26:54 t2 finished: result 0 (18 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/393691/23895/8932
  2026-11-27 10:28:05 d1 finished: result 0 (16 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 16/217772/27783/8440
  2026-11-27 10:48:10 v2 finished: result 0 (95 turns, 17 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 108/2628743/70944/25465
  2026-11-27 10:51:58 WARN: job v2 used 95 turns, over its cap of 80 (its own checks passed; accepted)
  2026-11-27 10:51:59 phase: tests-first (worker took 1805s)
  2026-11-27 10:52:07 phase: check (tests-first took 8s)
  2026-11-27 10:52:40 combined check: skips protocol connection metrics kit look arena puzzle (no job's change reaches them)
  2026-11-27 11:02:07 checks failed; fetching packages and trying once more
  2026-11-27 11:17:56 STOPPED: checks failed twice on the combined tree after t2 d1 v2
