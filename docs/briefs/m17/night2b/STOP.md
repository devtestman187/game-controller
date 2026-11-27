STOP 2026-11-27 03:05:56 docs/briefs/m17/night2b
cause: tools/review.sh found a FAIL after f1 f2 d2g (see .dart_tool/run-jobs/docs_briefs_m17_night2b/run-review.log); nothing of this wave is committed
class: review-fail
repair: run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 02:21:53 phase: worker (preflight took 815s)
  2026-11-27 02:21:54 skip d2w (already done)
  2026-11-27 02:21:54 skip d2f (already done)
  2026-11-27 02:22:09 phase: worker (worker took 16s)
  2026-11-27 02:22:10 skip d2x (already done)
  2026-11-27 02:22:10 skip d2h (already done)
  2026-11-27 02:22:11 skip d2i (already done)
  2026-11-27 02:22:26 phase: worker (worker took 17s)
  2026-11-27 02:22:27 start d2g
  2026-11-27 02:22:53 start f1
  2026-11-27 02:27:59 start f2
  2026-11-27 02:28:00 f1 finished: result 0 (33 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 58/1019793/36757/15652
  2026-11-27 02:32:52 f2 finished: result 0 (19 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 22/256161/21571/9404
  2026-11-27 02:54:33 d2g finished: result 0 (66 turns, 14 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 68/2572376/109479/36804
  2026-11-27 02:54:33 WARN: d2g logged 66 turns, 14 min but ran 32 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 02:54:34 phase: tests-first (worker took 1928s)
  2026-11-27 02:56:18 tests-first ok: packages/party_host/test/night_setup_screen_test.dart fails on the old code
  2026-11-27 02:57:19 phase: check (tests-first took 165s)
  2026-11-27 02:57:58 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-27 03:05:56 STOPPED: tools/review.sh found a FAIL after f1 f2 d2g (see .dart_tool/run-jobs/docs_briefs_m17_night2b/run-review.log); nothing of this wave is committed
