STOP 2026-11-22 08:56:47 docs/briefs/m16/identity1
cause: job i1d used 134 turns, over its cap of 120
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
  2026-11-22 08:28:08 i1f finished: result 4 (105 turns, 8 min)
  2026-11-22 08:28:11 i1f: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-22 08:33:17 i1e2 finished: result 4 (76 turns, 9 min)
  2026-11-22 08:33:17 STOPPED: job i1e2 used 76 turns, over its cap of 70
  RESULT: STOPPED: job i1e2 used 76 turns, over its cap of 70
  2026-11-22 HAND-FIX i1e2: brief turns raised 70 -> 120 (my cap was too low: 76 turns, work done); no code touched; i1d, i1f redo (killed by the stop)
  2026-11-22 08:33:44 RUN_MAX_MIN=69 min (computed backstop of the jobs still to do)
  2026-11-22 08:33:45 start at 1ccdf1a6 on m16
  2026-11-22 08:33:45 removed the last stop's STOP.md
  2026-11-22 08:33:56 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 08:34:17 skip i1a (already done)
  2026-11-22 08:34:17 skip i1b (already done)
  2026-11-22 08:34:18 skip i1c (already done)
  2026-11-22 08:34:39 start i1d
  2026-11-22 08:34:39 resume i1f (applied by hand, not committed yet)
  2026-11-22 08:35:05 start i1e2
  2026-11-22 08:51:28 i1e2 finished: result 4 (86 turns, 12 min)
  2026-11-22 08:51:29 i1e2: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-22 08:56:47 i1d finished: result 4 (134 turns, 18 min)
  2026-11-22 08:56:47 STOPPED: job i1d used 134 turns, over its cap of 120
