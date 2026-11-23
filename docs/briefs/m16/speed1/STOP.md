STOP 2026-11-23 12:13:05 docs/briefs/m16/speed1
cause: jobs that failed or passed their limit (parked, not committed): sp3 (their logs: docs/briefs/m16/speed1/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  cache-test-run1.txt
run.log (last 20 lines):
  2026-11-23 11:44:12 hand-fixed sp2: tests-first proof and worker review done (marked in done.txt)
  2026-11-23 11:44:12 skip sp2 (already done)
  2026-11-23 11:44:13 WARN: sp5 was committed by hand (3fdc97c3); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-23 11:44:14 hand-fixed sp5: tests-first proof and worker review done (marked in done.txt)
  2026-11-23 11:44:14 skip sp5 (already done)
  2026-11-23 11:44:14 wave 1 review: wave1-review-report.md does not cover sp2 sp5, so its review is wave1-sp2
  2026-11-23 11:44:37 start sp3
  2026-11-23 11:45:03 start sp4
  2026-11-23 11:48:23 start sp6
  2026-11-23 11:50:33 sp6 finished: result 4 (14 turns, 2 min)
  2026-11-23 11:50:35 sp6: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 11:53:25 sp4 finished: result 4 (47 turns, 8 min)
  2026-11-23 11:53:27 sp4: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 12:02:08 sp3 finished: result 4 (1 turns, 0 min)
  2026-11-23 12:02:08 job sp3 parked (result 4); its siblings continue
  2026-11-23 12:02:09 combined check: the tools suite runs (a job changed a file under tools/)
  2026-11-23 12:13:00 committed sp6: 9cf192a9 brief-check: WARN when a job's allow: holds only test files
  2026-11-23 12:13:02 committed sp4: f5965c0f runner: combined check runs affected suites, -j 4, formats job files
  2026-11-23 12:13:04 reviewed wave1-sp2: 8 finding(s)
  2026-11-23 12:13:04 STOPPED: jobs that failed or passed their limit (parked, not committed): sp3 (their logs: docs/briefs/m16/speed1/flash-<job>.log)
