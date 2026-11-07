job: m12 step3 s3b G4 — Shape Race on a PuzzleSession
stop: after G4. No FrameView, no registry in the apps, no phone app change (s3c). No change to the Arena (done in G3).
read: docs/briefs/m12/s3b-g1-plan.md §2 Shape Race, §3, §4, §5, §6 (the plan; with the decisions below it is the job) · docs/briefs/m12/s3b-g3.md (decisions Q1–Q8) · docs/design/m12-sessions.md §3, §4 (the contract; it wins) · docs/coding-guidelines.md · packages/game_kit/lib (GameSession, GameModule: build on them, don't change them) · packages/test_game/lib/src/{arena_session,arena_module}.dart (the pattern G3 set: follow it) · packages/puzzle_game (lib, test) · packages/party_host/test/{puzzle_screen_test,puzzle_results_test,pause_menu_test,keyboard_player_test}.dart

decisions:
- Q1 lazy load (s3b-g3.md): `ShapeRaceViewer` starts one cached `PuzzleLibrary.load()` on first build (one Future shared by every viewer) and draws nothing (`SizedBox.shrink`) until it resolves. A `puzzle` ID it can't find draws the text "Update the app to see this game". `createViewer` throws `FormatException` only for a setup missing a key or with a wrong type, never for an unknown puzzle.
- Q2 the viewer's clock uses `setup['timeLimitS']`.
- Q8 `PuzzleSnapshot.lerpTo` pairs pieces by index. Add a test that pins it: two snapshots of one `PuzzleGame` taken a step apart list the same piece IDs in the same order.
- `PuzzleSession` follows `ArenaSession`: it overrides `current` (typed `MatchSnapshot`), `snapshot()`, `step`, `resumed`, `dispose`. A finished match ends the view with `dispose(finished: true)` from the screen that ends it; if `PuzzlePlayView`'s dispose can't tell, it ends with `quit` and you say so in the report (don't change party_host).
- The report fires once (`_reported` in the session), on the step the match finishes.

do:
1 puzzle_game depends on game_kit. `PuzzleSession` (`puzzle_session.dart`, with `puzzleLayout`/`puzzleWatchLayout` moved in), `puzzle_events.dart`, `puzzle_report.dart`, `puzzle_status.dart`, `puzzle_module.dart` (`shapeRaceModule`, `ShapeRaceViewer`, `shapeRaceSetup`), as plan §2 and §4. Export the module and `shapeRaceSetup` from `puzzle_game.dart`.
2 `play_view.dart` becomes the thin view (~110): a Ticker calls `session.advance`, `setState`, and a post-frame `session.drawn()`; build is `MatchView(puzzle, session.current, timeLimitS)` as today. Constructor and test hooks (`PuzzlePlayViewState.match`, `.snapshot`) unchanged.
3 `lerpTo` on `MatchSnapshot` and `PuzzleSnapshot` in `snapshot.dart` (plan §4 table): positions lerp, piece `angle` the shortest arc in degrees, everything else from `this`, pieces/players only in `next` not drawn. `MatchSnapshot` and `PuzzleSnapshot` implement `GameSnapshot`. JSON unchanged.
4 Tests (plan §5): `snapshot_lerp_test` (t = 0 and 1 give each snapshot's `toJson()`; 350 → 10 at 0.5 is 0 (or 360); a piece only in `next` isn't in the result; held/holders/phase from `this`; the piece-order pin), `puzzle_session_test` (one `player_result` per player and one `round_end` after the finish and 100 more advances; the clock stops at the result; `view_start`'s setup has `puzzle`, `level`, `timeLimitS`, `teams`; statuses hidden on dispose; one view_end), `frame_size_test` (a real 4-player split boat match, 2 boards × 6 pieces, in a `FrameMessage` with 2 sounds, 4 acks and a 4-name roster: `jsonEncode(frame.toJson())` under 2500 bytes; print the size), `puzzle_module_test` (unknown puzzle shows the update text; a setup missing `teams` throws `FormatException`; a known puzzle draws a `MatchView` after the load).
5 Existing tests: no expected value changes (plan §5). If one has to change, list it old → new with the reason.
6 Report: line counts of every file touched or created (flag > 300); the frame size printed by the test; test counts per check before and after; anything in plan §6 R1–R8 that didn't hold.

rules: play_view.dart only shrinks; `game.dart` and `view.dart` untouched; no change to the rules (`PuzzleGame`, `PuzzleMatch`) or to any snapshot's JSON; no file over 400 (tests 500); every new lib file ≤ 300; no change in game_kit, test_game, party_host, tv_test_app or controller_app · tools/review.sh: no FAIL on your lines.
allow: packages/puzzle_game
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s3b-g4-report.md
