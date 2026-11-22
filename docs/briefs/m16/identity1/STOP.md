STOP 2026-11-22 16:34:34 docs/briefs/m16/identity1
cause: jobs that failed or passed their limit (parked, not committed): i1g2 (their logs: docs/briefs/m16/identity1/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  docs/design/m13-placed-look.png
  docs/design/puzzles/boat.png
  docs/design/puzzles/butterfly.png
  docs/design/puzzles/car.png
  (+12 more)
run.log (last 20 lines):
  2026-11-22 16:01:41 tests-first ok: packages/test_game/test/arena_identity_test.dart fails on the old code
  2026-11-22 16:01:43 hand-fixed i1f: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 16:01:43 skip i1f (already done)
  2026-11-22 16:01:44 WARN: i1e2 was committed by hand (dfbefcf3); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 16:01:44 hand-fixed i1e2: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 16:01:45 skip i1e2 (already done)
  2026-11-22 16:01:45 wave 2 review skipped: the committed wave2-review-report.md already covers i1d i1f i1e2
  2026-11-22 16:02:06 WARN: f1 was committed by hand (c188841b); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 16:03:55 tests-first ok: controller_app/test/host_lists_identity_test.dart fails on the old code
  2026-11-22 16:03:57 hand-fixed f1: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 16:03:57 skip f1 (already done)
  2026-11-22 16:04:19 WARN: i1g1 was committed by hand (d321bcdf); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 16:04:40 tests-first ok: packages/game_kit/test/view_characters_test.dart fails on the old code
  2026-11-22 16:04:54 tests-first ok: packages/test_game/test/arena_phone_identity_test.dart fails on the old code
  2026-11-22 16:04:56 hand-fixed i1g1: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 16:04:56 skip i1g1 (already done)
  2026-11-22 16:05:18 start i1g2
  2026-11-22 16:34:34 i1g2 finished: result 4 (161 turns, 23 min)
  2026-11-22 16:34:34 job i1g2 used 161 turns, over its cap of 120 (parked, siblings continue)
  2026-11-22 16:34:34 STOPPED: jobs that failed or passed their limit (parked, not committed): i1g2 (their logs: docs/briefs/m16/identity1/flash-<job>.log)
