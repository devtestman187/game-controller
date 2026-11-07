job: m12 bug 1107e fix G4 — back on the results goes to the game picker; two counting fixes; log the round's moments
stop: after G4.
read: docs/briefs/m12/bug-1107e-triage-report.md (yours: Claude approves Q 5 and Q 4's fixes with the answers below) · packages/party_host/lib/src/ui/{puzzle_screen,puzzle_screen_widgets,pause_menu,controller_menus}.dart · controller_app/lib/src/host/host_screen.dart · packages/game_kit/lib/src/game_session.dart · packages/metrics/lib/src/{session,session_player}.dart · packages/party_host/test/puzzle_results_test.dart · docs/briefs/m12/bug-1107d-a1-report.md (landed before you: the away slot)

Claude's answers: Q1 unknown, so every back is fixed · Q2 the TV too: one shared rule, back on the results always goes to the game picker · Q3 yes: the phone host's system back goes up inside the games first and stops hosting only from the picker · Q4 yes, stop the aliasing.

do:
1 Q 5 bullet 1: `PuzzleScreen` on the results → `leaveForGamePicker` for every back (the Back button, B on any pad, the route's pop).
2 Q 5 bullet 2: `host_screen.dart`'s system back pops the games navigator while it can, and stops hosting only at its root.
3 Q 4a: `SessionSummary.summary()` copies `rounds` and each player's `games` (no live references).
4 Q 4b: an input that arrived while the session was paused reports no `received_to_drawn` sample.
5 Logging on the host, tag `host` (short lines): a round starts (game, format, players), ends (result), a player leaves the results by back / Play again / Rematch, the round pauses / resumes and why (menu, host away, player away).
tests (each failing first): the triage's two results tests (B and the Back button land on the picker, no `PuzzleScreen`); the host screen's system back from the results and from the picker; the summary aliasing test; the paused-input test; one log test per kind of line. Existing tests: list any old → new.
in the report: test counts before and after, the files changed, the exact log lines.
rules: no lib file over 400 · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1107e-fix-report.md · packages/party_host · packages/game_kit · packages/metrics · packages/puzzle_game · controller_app/lib/src/host/host_screen.dart · controller_app/test · tv_test_app/test
check: format analyze host puzzle metrics phone tv
report: docs/briefs/m12/bug-1107e-fix-report.md
