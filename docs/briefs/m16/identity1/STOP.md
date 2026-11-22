STOP 2026-11-22 08:17:25 docs/briefs/m16/identity1
cause: job i1e used 151 turns, over its cap of 120
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
  2026-11-22 00:34:14 start i1b
  2026-11-22 00:36:42 i1a2 finished: result 0 (31 turns, 2 min)
  2026-11-22 01:30:30 STOPPED: stop file
  2026-11-22 01:50:00 HAND-FIX i1b: applied from job worktree flash-20261122-003415-326933 after base fix (i1a2 committed); combined check green (707 s); tests-first proof and worker review not run
  2026-11-22 07:56:44 RUN_MAX_MIN=85 min (computed backstop of the jobs still to do)
  2026-11-22 07:56:44 start at f08753b2 on m16
  2026-11-22 07:56:44 removed the last stop's STOP.md
  2026-11-22 07:56:57 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 07:57:18 skip i1a (already done)
  2026-11-22 07:57:19 WARN: i1b was committed by hand (05c5d72b); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 07:59:30 tests-first ok: controller_app/test/identity_change_link_test.dart fails on the old code
  2026-11-22 07:59:43 tests-first ok: controller_app/test/identity_nickname_test.dart fails on the old code
  2026-11-22 07:59:45 hand-fixed i1b: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 07:59:45 skip i1b (already done)
  2026-11-22 07:59:46 skip i1c (already done)
  2026-11-22 08:00:08 start i1d
  2026-11-22 08:00:34 start i1e
  2026-11-22 08:08:13 start i1f
  2026-11-22 08:17:25 i1e finished: result 4 (151 turns, 12 min)
  2026-11-22 08:17:25 STOPPED: job i1e used 151 turns, over its cap of 120
