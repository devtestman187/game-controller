STOP 2026-11-24 12:27:23 docs/briefs/m16/bugs4
cause: checks failed on the combined tree after nc1: analyze cannot be fixed by a retry
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  analyze     (exit 3, 23s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-122652/analyze.log
          error - packages\connection\lib\src\client_messages.dart:38:5 - The type 'Message' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'NightEndMessage()'. Try adding a default case or cases that match 'NightEndMessage()'. - non_exhaustive_switch_statement
          error - packages\connection\lib\src\host_connection.dart:202:5 - The type 'Message' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'NightEndMessage()'. Try adding a default case or cases that match 'NightEndMessage()'. - non_exhaustive_switch_statement
files outside allow (flash log):
  none found
run.log (last 20 lines):
  METRICS b040win worker=claude model=claude-haiku-5-5 turns=24 in=30 out=20503 cache=599123 min=4.1 wall=6.7 result=4
  METRICS run-review worker=claude model=claude-haiku-5-5 turns=44 in=38 out=58301 cache=1125874 min=4.5 wall=- result=0
  METRICS wave1-review worker=claude model=claude-haiku-5-5 turns=20 in=28 out=18998 cache=480599 min=1.6 wall=- result=0
  METRICS wave2-review worker=claude model=claude-haiku-5-5 turns=13 in=18 out=11039 cache=234360 min=1.0 wall=- result=0
  2026-11-24 12:17:52 DONE: every job is committed. Claude reads the Summary of docs/briefs/m16/bugs4/REVIEW.md, verifies its findings and writes one fix brief
  RESULT: DONE: 3 jobs, 29 min
  2026-11-24 12:21:42 RUN_MAX_MIN=244 min (computed backstop of the jobs still to do)
  2026-11-24 12:21:42 start at e2218b16 on m16
  2026-11-24 12:21:42 worker: claude
  2026-11-24 12:22:05 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 12:22:21 skip b040fit (already done)
  2026-11-24 12:22:21 skip b040awards (already done)
  2026-11-24 12:22:37 skip b040win (already done)
  2026-11-24 12:22:53 start nc1
  2026-11-24 12:26:22 nc1 finished: result 4 (43 turns, 3 min)
  2026-11-24 12:26:23 nc1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 12:26:36 tests-first ok: packages/connection/test/night_end_gate_test.dart fails on the old code
  2026-11-24 12:26:39 tests-first ok: packages/protocol/test/night_end_test.dart fails on the old code
  2026-11-24 12:26:52 combined check: the tools suite is skipped (no job changed a file under tools/)
  2026-11-24 12:27:23 STOPPED: checks failed on the combined tree after nc1: analyze cannot be fixed by a retry
