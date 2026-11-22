STOP 2026-11-22 08:33:18 docs/briefs/m16/identity1
cause: job i1e2 used 76 turns, over its cap of 70
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
          error - packages\connection\lib\src\client_messages.dart:38:5 - The type 'Message' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'PlayersMessage()'. Try adding a default case or cases that match 'PlayersMessage()'. - non_exhaustive_switch_statement
          error - packages\connection\lib\src\host_connection.dart:188:5 - The type 'Message' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'PlayersMessage()'. Try adding a default case or cases that match 'PlayersMessage()'. - non_exhaustive_switch_statement
        00:00 +0 -1: loading test\client_ask_test.dart [E]
          Failed to load "test\client_ask_test.dart":
          lib/src/host_connection.dart:188:13: Error: The type 'Message' is not exhaustively matched by the switch cases since it doesn't match 'PlayersMessage()'.
          lib/src/client_messages.dart:38:13: Error: The type 'Message' is not exhaustively matched by the switch cases since it doesn't match 'PlayersMessage()'.
        00:00 +0 -2: loading test\client_view_test.dart [E]
  (+259 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 08:08:13 start i1f
  2026-11-22 08:17:25 i1e finished: result 4 (151 turns, 12 min)
  2026-11-22 08:17:25 STOPPED: job i1e used 151 turns, over its cap of 120
  2026-11-22 08:17:27 reviewed wave1: 8 finding(s)
  RESULT: STOPPED: job i1e used 151 turns, over its cap of 120
  2026-11-22 HAND-FIX i1e: applied from job worktree flash-20261122-080034-737458 after the 151-turn stop; 5 tests fail (host_chip x2, phone_metrics, m9 x2), finished by i1e2; tests-first proof and worker review not run
  2026-11-22 08:18:35 RUN_MAX_MIN=69 min (computed backstop of the jobs still to do)
  2026-11-22 08:18:35 start at cb3e5a7d on m16
  2026-11-22 08:18:35 removed the last stop's STOP.md
  2026-11-22 08:18:46 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 08:19:07 skip i1a (already done)
  2026-11-22 08:19:08 skip i1b (already done)
  2026-11-22 08:19:08 skip i1c (already done)
  2026-11-22 08:19:29 start i1d
  2026-11-22 08:19:55 start i1f
  2026-11-22 08:20:21 start i1e2
  2026-11-22 08:28:08 i1f finished: result 4 (105 turns, 8 min)
  2026-11-22 08:28:11 i1f: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-22 08:33:17 i1e2 finished: result 4 (76 turns, 9 min)
  2026-11-22 08:33:17 STOPPED: job i1e2 used 76 turns, over its cap of 70
