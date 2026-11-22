STOP 2026-11-21 23:17:16 docs/briefs/m16/identity1
cause: checks failed twice on the combined tree after i1b i1c (see .dart_tool/run-jobs/docs_briefs_m16_identity1/run-check.log); nothing of this wave is committed
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
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
  2026-11-21 21:34:49 start at dd51e607 on m16
  2026-11-21 21:34:49 run-base dd51e6075ce363a119e853090ce6e3360826d2ba
  2026-11-21 21:35:03 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-21 21:35:03 start i1a
  2026-11-21 21:35:29 start i1b
  2026-11-21 21:35:54 start i1c
  2026-11-21 21:41:34 i1a finished: result 5 (66 turns, 6 min)
  2026-11-21 21:48:32 i1b finished: result 4 (57 turns, 8 min)
  2026-11-21 21:48:34 i1b: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png 
  2026-11-21 21:48:34 i1c finished: result 0 (61 turns, 6 min)
  2026-11-21 21:48:53 tests-first: packages/connection/test/identity_reservation_test.dart passes on the old code, exempt by its brief
  2026-11-21 21:48:58 tests-first ok: packages/protocol/test/identity_wire_test.dart fails on the old code
  2026-11-21 21:49:12 tests-first ok: packages/toy_look/test/toy_character_name_test.dart fails on the old code
  2026-11-21 22:30:45 checks failed; fetching packages and trying once more
  2026-11-21 23:17:16 STOPPED: checks failed twice on the combined tree after i1b i1c (see .dart_tool/run-jobs/docs_briefs_m16_identity1/run-check.log); nothing of this wave is committed
