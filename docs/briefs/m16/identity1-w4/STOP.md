STOP 2026-11-23 04:19:19 docs/briefs/m16/identity1-w4
cause: checks failed twice on the combined tree after w4f2
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  connection  (355 passed, exit 1, 16s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-041229/connection.log
        00:00 +66 -1: test\identity_host_test.dart: webSocket the players message goes to every identity phone on join, leave and change, and to no other [E]
          Expected: PlayerCharacter:<PlayerCharacter(2, bow)>
            Actual: PlayerCharacter:<PlayerCharacter(2, cap)>
        00:00 +74 -2: test\identity_host_test.dart: inProcess the players message goes to every identity phone on join, leave and change, and to no other [E]
        00:11 +355 -2: Some tests failed.
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-23 03:47:50 committed w4g: f3b59242 M16 w4g: test the chip's host answer, identity join, palette words
  2026-11-23 03:47:51 wave review skipped: wave 1 is the whole run, the run review covers it
  METRICS w4f worker=claude model=claude-haiku-5-5 turns=9 in=14 out=7239 cache=148797 min=0.6 result=0
  METRICS w4g worker=claude model=claude-haiku-5-5 turns=19 in=30 out=15181 cache=433753 min=5.5 result=4
  2026-11-23 03:47:58 DONE: every job is committed. Claude reads the Summary of docs/briefs/m16/identity1-w4/REVIEW.md, verifies its findings and writes one fix brief
  RESULT: DONE: 2 jobs, 8 min
  2026-11-23 03:50:43 RUN_MAX_MIN=69 min (computed backstop of the jobs still to do)
  2026-11-23 03:50:43 start at 928a9681 on m16
  2026-11-23 03:50:43 worker: claude
  2026-11-23 03:50:57 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 03:51:18 start w4f2
  2026-11-23 03:51:44 start f1
  2026-11-23 04:03:00 w4f2 finished: result 4 (33 turns, 7 min)
  2026-11-23 04:03:02 w4f2: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 04:05:05 f1 finished: result 4 (55 turns, 10 min)
  2026-11-23 04:05:05 job f1 used 55 turns, over its cap of 35 (parked, siblings continue)
  2026-11-23 04:05:22 tests-first ok: packages/connection/test/identity_reserve_minute_test.dart fails on the old code
  2026-11-23 04:05:24 combined check: the tools suite is skipped (no job changed a file under tools/)
  2026-11-23 04:12:24 checks failed; fetching packages and trying once more
  2026-11-23 04:19:19 STOPPED: checks failed twice on the combined tree after w4f2
