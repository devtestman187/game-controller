job: m17prep e0f — 8-phone fake-controller load tool (host load, snapshot size at 8 players)
stop: no lib change, no new capability, no game rule; measurements only. Do not run it against a real device.
read: docs/briefs/templates/COMMON.md · packages/connection/test/helpers.dart:1-110 (startHost, newClient, in-process transport) · packages/connection/test/input_test.dart:1-40 (a phone's input reaches the host) · packages/puzzle_game/test/cat_snapshot_test.dart:10-30,55-95 (the worst-case snapshot and its byte count) · packages/puzzle_game/lib/src/snapshot.dart:52-80,139-170 (PuzzleSnapshot, maxBytes 2048) · city-rush plan, quoted: "e0f: a fake-controller 8-phone load tool (host load, snapshot size), seeded test"
changes: load8 · LOAD8 · loadEightPhones · eight_phone_load_test · snapshot_eight_players_test
turns: 60
expected-min: 35
tests-first: exempt a measuring tool: the cases pin the tool's own counts, not game behaviour
do:
1 New packages/connection/test/load_eight_phones_test.dart: start one HostServer on the in-process transport (helpers.dart), connect 8 ControllerClients (ids phone-1..phone-8), each sends seeded (`Random(17)`) inputs, 60 per second for 3 simulated seconds (use a real short loop; keep the plain run under 15 s). Assert: all 8 are connected, no phone was dropped, every phone's last input reached the host snapshot, and the host's counted inputs equal the sum of the phones' `inputsSent` (ordering kept per phone). With LOAD8=1 (a dart-define) the loop runs 30 s and the test prints one summary line to stdout (via stdout.writeln, not print) (inputs per second, wall ms per 1000 inputs, max host event lag you can measure). Same seed gives the same input counts (a test runs twice and compares).
2 New packages/puzzle_game/test/snapshot_eight_players_test.dart: the worst-case night match snapshot of cat_snapshot_test.dart with 4, 6 and 8 players (players map and per-player fields scaled) and the full pop-up list: record the encoded byte count for each and assert 4 players stays under PuzzleSnapshot.maxBytes; 6 and 8 are only recorded (printed in the report, not asserted, because the 2 KB budget at 6-8 players is the open question B10 decides). No debugPrint in the test; the report carries the numbers.
3 New tools/load8.sh: `bash tools/load8.sh` runs the two test files with LOAD8=1 and prints the two result lines; one comment block says what it measures. No other script change.
4 Report (docs/briefs/m17/m17prep/e0f-report.md): the numbers (inputs/s, lag, bytes at 4/6/8), whether 8 players fit 2048 bytes, and how to run the tool.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error on them.
allow: packages/connection/test/load_eight_phones_test.dart · packages/puzzle_game/test/snapshot_eight_players_test.dart · tools/load8.sh
check: format analyze
report: docs/briefs/m17/m17prep/e0f-report.md
