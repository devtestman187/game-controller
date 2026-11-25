STOP 2026-11-25 13:49:23 docs/briefs/m16/m165
cause: tools/review.sh found a FAIL after a2 (see .dart_tool/run-jobs/docs_briefs_m16_m165/run-review.log); nothing of this wave is committed
class: review-fail
repair: run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 13:27:10 start at 7529db41 on m16
  2026-11-25 13:27:10 worker: claude
  2026-11-25 13:27:11 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-25 13:27:11 run-base 7529db41051da2f124f214ceb7aacdb4f7d8623d
  2026-11-25 13:27:20 phase: preflight
  2026-11-25 13:27:29 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-25 13:27:44 phase: worker (preflight took 24s)
  2026-11-25 13:27:45 start a1s
  2026-11-25 13:28:10 start a1h
  2026-11-25 13:28:36 start a2
  2026-11-25 13:38:30 a2 finished: result 0 (36 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 50/956496/42337/20499
  2026-11-25 13:44:01 a1s finished: result 0 (95 turns, 13 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 98/2673829/83326/25155
  2026-11-25 13:44:01 job a1s kept /e/AI/game-controller-m16-jobs/flash-20261125-132746-1866 (apply: no; worker result 0, 95 turns, 13 min)
  2026-11-25 13:46:02 a1h finished: result 4 (119 turns, 14 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 140/6367530/124089/67300
  2026-11-25 13:46:02 job a1h kept /e/AI/game-controller-m16-jobs/flash-20261125-132811-2123 (apply: no; worker result 4, 119 turns, 14 min)
  2026-11-25 13:46:03 phase: tests-first (worker took 1099s)
  2026-11-25 13:47:17 tests-first ok: controller_app/test/result_card_pad_test.dart fails on the old code
  2026-11-25 13:47:31 phase: check (tests-first took 88s)
  2026-11-25 13:47:48 combined check: skips protocol connection metrics kit look arena puzzle host tv tools (no job's change reaches them)
  2026-11-25 13:49:22 STOPPED: tools/review.sh found a FAIL after a2 (see .dart_tool/run-jobs/docs_briefs_m16_m165/run-review.log); nothing of this wave is committed
