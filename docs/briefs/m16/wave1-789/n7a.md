job: M16 wave1-789 n7a — one test pins the awards from start card to final totals, ties included, TV host and phone host
stop: Tests only; no lib change. If a case fails because lib is wrong, report it (file:line) and mark that test skip with the reason; a real bug goes to the driver.
read: docs/briefs/templates/COMMON.md · packages/party_host/test/support/night_harness.dart · packages/party_host/test/support/all_looks.dart · packages/party_host/test/night_reveal_test.dart:1-60 · packages/party_host/test/night_award_results_test.dart (tie cases) · packages/party_host/test/end_night_arena_test.dart:54-96 (phone host) · packages/party_host/lib/src/night/night_state.dart:164-272 · decision (owner, Nov 24, Q1 A and Q8): host side only; "tied players each get one" (PRD item 7 acceptance).
changes: night_awards_flow_test.dart
tests-first: exempt (the job is a test file over existing lib)
turns: 70
expected-min: 30
do:
1 NEW packages/party_host/test/night_awards_flow_test.dart. Start a three-round night with threeAwards and three players. The start card's three award names equal, in order, the names the reveal shows one after another (pump nightAwardRevealMs between), and the final scores equal each player's round points plus 3 per award won.
2 A tie: two players level on the best value of one award each win it, each total +3, the reveal names both. An award nobody won ("Not won tonight") adds 0.
3 Run the flow in both looks (forEachLook, menu and TV) and once at 640x360 as a phone host (as end_night_arena_test's phone-host case does).
4 Report: the cases, and anything that disagreed with the host's own totals.
repair: the file packages/party_host/test/night_awards_flow_test.dart already exists (a first attempt, stopped mid-debug); finish it, do not start over. Failure: at the first reveal the winner name "Phone 2" (_names) is not found (night_awards_flow_test.dart:130), so the reveal screen resolves names from the roster (gamePlayersProvider) and the joined p2 and p3 do not reach it in the fresh reveal mount: find how NightText.playerName gets names (night_reveal_widgets.dart) and give the reveal mount the same roster (TestRoster.put in night_harness.dart, or the way arena_night_test.dart gets its phones into gamePlayersProvider). Remove the debug block with reason BISECT (the early return at i == 0), keep every check. Analyze must show no dead_code.
allow: packages/party_host/test/night_awards_flow_test.dart
check: format analyze
report: docs/briefs/m16/wave1-789/n7a-report.md
