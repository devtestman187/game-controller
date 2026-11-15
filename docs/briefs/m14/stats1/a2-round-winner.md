job: M14 stats1 a2-round-winner: winner, draw and players in the rounds CSV; robot wins recorded
stop: after it. No frames, no start offset.
read: packages/metrics/lib/src/session.dart (roundEnded ~215-245: the round JSON has players, winner (player number), winners, draw) · packages/metrics/lib/src/report_rounds.dart · packages/party_host/lib/src/session_recorder.dart (round_end ~80-100) · packages/test_game/lib/src/arena_session.dart ~165-180 and ~218 (a robot win records no player) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: the rounds CSV needs who won, arena rounds included; a robot win is invisible today. Privacy: never export names or device IDs.
do:
1 TEST FIRST, new files packages/metrics/test/round_winner_csv_test.dart and packages/test_game/test/robot_win_record_test.dart (must fail on old code).
2 Record a robot win explicitly: the arena round_end data gets robotWin: true when game.winnerId == roboPlayerId (playerId stays null so no stats count Robo). session_recorder passes it on; metrics roundEnded takes robotWin and writes robot: true into the round JSON only when true. Old rounds without it still parse.
3 Rounds CSV, appended at the END of the header (after host_app, which job a1 adds): winner (the player number / seat index from the round JSON, the word robot, or empty), draw (1 or empty), players (the count). Never a name or id.
tests-first: each new test must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src · packages/metrics/test · packages/party_host/lib/src/session_recorder.dart · packages/party_host/test · packages/test_game/lib/src/arena_session.dart · packages/test_game/test · docs/briefs/m14/stats1/a2-round-winner-report.md
check: format analyze metrics arena host
report: docs/briefs/m14/stats1/a2-round-winner-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
