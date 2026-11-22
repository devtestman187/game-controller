STOP 2026-11-21 18:19:41 docs/briefs/m16/process2
cause: jobs that failed or need applying by hand: f2:4 (their logs: docs/briefs/m16/process2/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  tv_test_app/windows/flutter/generated_plugin_registrant.cc
  tv_test_app/windows/flutter/generated_plugin_registrant.h
  tv_test_app/windows/flutter/generated_plugins.cmake
run.log (last 20 lines):
  2026-11-21 16:14:31 committed p2-split: 886e8a58 Runner: move its steps and reviews into sourced files
  2026-11-21 16:14:32 start p2-wire
  2026-11-21 16:31:26 p2-wire finished: result 0 (102 turns, 16 min)
  2026-11-21 16:40:35 committed p2-wire: 573e61a2 M16 process2: the runner writes STOP.md, locks and times itself
  2026-11-21 16:44:23 reviewed wave4: 12 finding(s)
  2026-11-21 16:44:24 start the run's review
  2026-11-21 16:52:51 DONE: every job is committed. Claude reads the Summary of docs/briefs/m16/process2/REVIEW.md, verifies its findings and writes one fix brief
  2026-11-21 16:54:45 start at 25a8d244 on m16
  2026-11-21 16:54:56 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-21 16:54:57 start f1
  2026-11-21 16:55:24 start f2
  2026-11-21 16:55:50 start f3
  2026-11-21 17:26:11 f1 finished: result 4 (85 turns, 31 min)
  2026-11-21 17:26:13 f1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-21 18:08:40 f2 finished: result 4 (147 turns, 73 min)
  2026-11-21 18:08:41 f3 finished: result 0 (59 turns, 15 min)
  2026-11-21 18:19:38 committed f1: 42b8a1e3 runner: end the run on a signal, keep findings, rescue churn-only jobs
  2026-11-21 18:19:40 committed f3: 432d29f7 M16 process2 f3: validate the run-stop and wait-run env knobs
  2026-11-21 18:19:40 wave review skipped: wave 1 is the whole run, the run review covers it
  2026-11-21 18:19:41 STOPPED: jobs that failed or need applying by hand: f2:4 (their logs: docs/briefs/m16/process2/flash-<job>.log)
