job: m12 step3 s3b G3 — game_kit and the Arena on a GameSession
stop: after G3. Don't touch puzzle_game (G4). No FrameView, no phone app change (s3c).
read: docs/briefs/m12/s3b-g1-plan.md (the plan; with the decisions below it is the job) · docs/design/m12-sessions.md §3, §4, §5 (the contract; it wins) · docs/coding-guidelines.md · packages/test_game (lib, test) · packages/connection/lib/src/{game_host,memory_game_host,server_game_host}.dart · packages/party_host/test/{game_screen_test,game_players_test}.dart

decisions (answers to s3b-g1-plan §7):
- Q1 Lazy load accepted (G4): the Shape Race viewer starts one cached `PuzzleLibrary` load and draws nothing until it resolves; a puzzle ID it can't find shows the same "Update the app to see this game" as a version mismatch. `createViewer` never throws for a missing puzzle.
- Q2 Yes: the viewer's clock uses `setup.timeLimitS`. A mid-match change of the playtest setting isn't mirrored (playtest only).
- Q3 The input latch is approved and is part of `GameSession`: sample `players` and `gamepad` every advance, OR the buttons seen since the last step into the next step's buttons, analogues from the newest sample. Why: local (keyboard) players have no 50 ms hold (`server_game_host.dart:146`), and a phone host's display may run at 120 Hz, where half the advances run no step. Test it: a press set and cleared within one no-step advance still reaches exactly one step.
- Q4 Yes, `n` starts at 0.
- Q5 Keep `PlayerFeed` and `feedsOf` as they are: party_host's `game_players_test.dart:7,29` uses them. Add `ArenaRoster` for drawing only.
- Q6 Yes: `ArenaSnapshot`, `ArenaPlayerView` and the `snapshot()` extension move to `arena_snapshot.dart` as a pure move in this job, then `lerpTo` is added there.
- Q7 Yes: the Arena's session ends with `quit` (a won round isn't the session's end).
- Q8 Yes, by index (G4): `PuzzleSnapshot` lists pieces in a stable order (`snapshot.dart:132`); add a test that pins it.

do:
1 packages/game_kit as plan §1, with the latch (Q3) in `GameSession`. Root pubspec and tools/check.sh (`kit`) as the plan says. Also add `kit` to docs/dev-tools.md's list of checks.
2 The Arena as plan §2 (Arena) and §4 (arenaModule, `lerpTo`, roster): `ArenaSession`, the thin `ArenaView` (same constructor and test hooks), `arena_snapshot.dart` (move first, then `lerpTo`), `arena_view_widgets.dart`, `arena_painter.dart`, `arena_module.dart`. test_game depends on game_kit.
3 Timing exactly as plan §3.
4 Tests: game_kit's session_test and registry_test (plan §5, plus the latch case above); test_game's arena_snapshot_test and arena_session_test (plan §5). Existing tests: no expected value changes expected (plan §5); if one has to change, list it old → new with the reason.
5 Report: line counts of every file touched or created (flag > 300); the move proof for arena_snapshot.dart (`tools/review.sh --strings` before `lerpTo` is added, and the test counts); test counts per check before and after.

rules: arena.dart only shrinks; no file over 400 (tests 500); every new lib file ≤ 300; no change to `ArenaGame`'s rules or `ArenaSnapshot`'s JSON; `ArenaView`'s constructor unchanged; no change in party_host or tv_test_app lib code · tools/review.sh: no FAIL on your lines.
allow: packages/game_kit · packages/test_game · pubspec.yaml · tools/check.sh · docs/dev-tools.md
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s3b-g3-report.md
