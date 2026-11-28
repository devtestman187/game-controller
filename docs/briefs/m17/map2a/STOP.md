STOP 2026-11-28 03:23:40 docs/briefs/m17/map2a
cause: tools/review.sh found a FAIL after m2b (see .dart_tool/run-jobs/docs_briefs_m17_map2a/run-review.log); nothing of this wave is committed
class: review-fail
repair: run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-28 02:59:35 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-28 03:00:47 phase: worker (preflight took 78s)
  2026-11-28 03:00:47 start m2a
  2026-11-28 03:06:20 m2a finished: result 0 (32 turns, 5 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 44/794468/56924/24789
  2026-11-28 03:06:20 phase: tests-first (worker took 333s)
  2026-11-28 03:07:34 tests-first ok: packages/party_host/test/city/art/city_painter_test.dart fails on the old code
  2026-11-28 03:08:10 phase: check (tests-first took 110s)
  2026-11-28 03:08:15 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-28 03:11:24 phase: apply (check took 194s)
  2026-11-28 03:11:26 committed m2a: a1606249 map2a: static 2.5D city painter with image cache
  2026-11-28 03:11:26 phase: review (apply took 2s)
  2026-11-28 03:11:47 phase: worker (review took 21s)
  2026-11-28 03:11:48 start m2b
  2026-11-28 03:18:03 m2b finished: result 0 (32 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 52/1535824/84630/56935
  2026-11-28 03:18:03 phase: tests-first (worker took 376s)
  2026-11-28 03:19:12 tests-first ok: packages/party_host/test/city/art/city_overlay_painter_test.dart fails on the old code
  2026-11-28 03:19:21 tests-first ok: packages/party_host/test/city/art/city_scene_test.dart fails on the old code
  2026-11-28 03:20:14 phase: check (tests-first took 131s)
  2026-11-28 03:20:21 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-28 03:23:40 STOPPED: tools/review.sh found a FAIL after m2b (see .dart_tool/run-jobs/docs_briefs_m17_map2a/run-review.log); nothing of this wave is committed
