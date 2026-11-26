# CI evidence (Nov 26, gh run view, read-only)
Job analyze-test-android, limit 30 min. Four of the last six main runs ended `cancelled` at 30m15s-30m20s (45878236414, 45734096031, 45627329271, 45217950023): the limit, not a push (concurrency cancels show the same word but these all ran 30 min). Passing 45472778922 (Nov 24): 28m21s; passing 44922343956 (Nov 21): 26m05s.

Step times (min:s), Nov 21 / Nov 24 / Nov 26:
- Test host 3:23 / 3:53 / 4:30-4:50; Test controller 2:05 / 2:27 / 3:28; test game 0:36 / 0:32 / 0:38; connection 0:12 / 0:14 / 0:14; protocol 0:05 / 0:05 / 0:06; TV 0:29 / 0:33 / 0:37.
- Coverage 10:18 / 11:40 / 15:00 (Nov 23 16:15, Nov 25 15:47, Nov 26 early 14:09).
- Build controller APK 6:08 / 6:30; Build TV APK 1:34 / 1:26 (never reached on the cancelled runs).

Duplicate: the Coverage step runs tools/coverage.sh, which runs `flutter test --coverage` in all 10 packages (protocol, connection, metrics, game_kit, toy_look, test_game, puzzle_game, party_host, controller_app, tv_test_app). The six plain Test steps run the same tests of protocol, connection, test_game, party_host, controller_app, tv_test_app a second time (about 9 min 50 s on Nov 26). Coverage is a superset (it also runs metrics, game_kit, toy_look, puzzle_game, which no Test step covers) and exits 1 if any package's tests fail (ci.yml's step does `exit $status`).

Why slower: test files 502 (Nov 24) to 542 (Nov 26) in total, controller_app 91 to 117 test files (+29%) against Test controller +42%, party_host 150 to 154; Nov 21 to 26 total 451 to 542 (+20%). The rise is steady over four runs, so it is test growth (the bug batches), not runner variance.

windows-desktop (limit 30): total 4:00 (Nov 24), 4:40 (Nov 21), 5:28 (Nov 26); no test steps, only the Windows build (2:12-3:20). Margin about 25 min: leave at 30.

Patch (ci-timeout.patch): timeout-minutes 30 to 45 for analyze-test-android; delete the six Test steps; rename Coverage to "Test with coverage (every package once; ...)" with a comment.
Expected new timings: tests once with coverage about 15-16 min (coverage step already includes them) instead of 15 + 10; whole job about 1 + 15.5 + 6.5 + 1.5 + setup 1 = 26-27 min under the 45 limit, and about 36 min if the tests keep growing 20% before the next cut. Check on the next push: job time, that the Coverage step fails when a test fails (it does by exit status), and that the Step Summary still shows the table.
