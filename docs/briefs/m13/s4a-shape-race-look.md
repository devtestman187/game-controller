job: M13 step 4a: Shape Race drawn in the toy look (board, tray, targets, pieces, players' dots, HUD, mirror), with the snap and wrong-drop motion; the worker is 4b
pub: yes
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D1, D5, D8, D11, D12), 3, 4, 5 (the Shape Race bullet) and 7 · packages/toy_look/lib · packages/puzzle_game/lib/src (all of it) · packages/puzzle_game/test (view_test, mirror_test, mirror_png_test, camera_test and support) · packages/party_host/test/support/toy_fonts.dart · packages/party_host/lib/src/ui/game_screen.dart (how the host shows the game) · controller_app/lib/src/ui/joined_view.dart (how a phone shows it) · tools/review.sh (the `layers` check) · docs/review-rules.md · docs/coding-guidelines.md

Shape Race is still drawn in M12's dark colours. This job draws it in the look, on the host and on a joined phone alike, since both draw through `PuzzleView`/`MatchView`. The player's dot stays a dot here: 4b turns it into the worker.

Claude's rules:
1. **The look reaches the painters.**
   - puzzle_game depends on toy_look (a path dependency, as party_host has).
   - `PuzzleView` and `MatchView` read `ToyLookScope.of(context)` and hand the look to their painters. Only files the `layers` check allows import toy_look: view.dart with its parts, and play_view.dart. camera.dart and the rules files don't.
   - Tests that pump a view put a `ToyLookScope` above it; add a helper in test/support.
2. **Sizes in the world.** The painters draw in world units: the canvas is scaled by the field's scale. Every size the look gives in pixels (outline width, shadow offset, dash, corners) is divided by that scale, so on screen it is the look's pixel size. Build one `ToyShapeStyle` per paint, with the look's ink and the world-unit outline and shadow, and draw every game object with `toyShape` (with `look.shade`, null when effects are off).
3. **What each thing becomes** (design section 5):
   - **Behind the field:** the look's `background`, flat. The dotted, drifting sky is step 6.
   - **The board:** a `board` play mat with the ink edge, `cardCorner` corners and the look's hard shadow.
   - **The tray:** a `tray` strip with the ink edge.
   - **Targets:** a dashed ink outline, with a faint fill at 0.25 alpha: the piece's own colour on a level with coloured outlines (Easy), `targetNeutral` otherwise. A ready target and a hint keep their meaning, in `good` and `focus`.
   - **Pieces:** `toyShape` in the puzzle's own piece colour (the puzzle's data, not a token). A held piece's shadow falls twice as far, so it looks lifted.
   - **A wrong drop:** a `bad` outline in place of the ink, the ✗ mark in `bad` with an ink edge, and a wobble (below).
   - **A right drop:** the ✓ mark in `good` with an ink edge, and a boing (below).
   - **A player's dot:** `paintToyBadge` with the player's number, at today's dot size. The call flash keeps its meaning, in `focus`.
   - **The HUD:**
     - Its text is in the look's families: the clock in `type.clock`'s, the counts in `type.button`'s. It is `onBackground` on the background.
     - In the warning time (`snapshot.warning`), the clock sits on a `bad` pill with ink text: red text on the sky would fail 4.5:1.
     - The time bar is a `good` fill on a `paper` track with the ink edge, `bad` in the warning time.
     - The phone's HUD panel over the board (`_hudPanel`) becomes `paper` at 0.9 alpha with the ink edge and ink text.
   - **The mirror** (the other side's board on a phone): its frame is the ink edge with an inner band in the other side's colour, `player(2)`, as the orange is today (m12-opponent-mirror rule 4: same meaning, from the look). Its board and pieces are drawn as above, smaller.
4. **The motion** (design section 5; D8: with effects off, none of it moves):
   - **Boing:** a piece that has just locked scales 1.0 → 1.12 → 1.0 over 150 ms about its centre. A ✓ sparkle grows and fades over 400 ms.
   - **Wobble:** a piece that has just been dropped wrong turns +3°, −3°, 0 over 120 ms about its centre.
   - **What is worked out from the snapshots:** both come from the snapshots, nothing from the rules or the protocol, so a joined phone shows the same as the host. A small `PieceMoments` (its own file, no Flutter or toy_look import, so it is a rules-side helper with tests) is fed each new snapshot with the time it arrived. It notes when each piece's state changed to `locked` or to `wrong`, and answers how long ago that was. The views keep one in their `State` (they become stateful).
   - **Time and repaints:** the view takes the time from an injectable clock, defaulting to a `Stopwatch`. It repaints when a new snapshot arrives, as now: the game sends one every frame while a round runs, so no ticker of its own.
   - **Starting views:** a view built mid-round, or a piece already locked in its first snapshot, shows no motion.
5. **The text measure.** `PuzzleCamera._glyphEm` estimates the HUD's text width (design section 5). Re-measure it for Fredoka at the HUD's weight: with the look's fonts loaded (`toy_fonts.dart`'s way), the estimate for the widest clock ("88:88") and score strings must be no less than the real width and no more than 15 % over. Keep camera.dart free of toy_look: the number lives there.
6. **Colours:** after the job no `Color(0x` or `Colors.` is left in packages/puzzle_game/lib, bar `Color(spec.color)` (puzzle data). Every colour is a token. List the grep in the report.
7. **Contrast:** HUD text is onBackground on the background, or ink on paper or a fill. Text is never `good` or `bad` on the sky.
8. **Cost:** with 4 players and the busiest puzzle, `paint` makes no more `TextPainter`s than today. One `ToyShapeStyle` per paint, not per piece.
9. Change no rule, layout, size, tolerance, camera, or protocol field. The mirror's placement rules (m12-opponent-mirror) are unchanged; mirror_test must pass as it is, bar colours it pinned.
10. Files under 400 lines, functions under 60; split the painters into parts if they grow.

tests (each failing first, unless it guards a fit):
- **PieceMoments:** a piece turning `locked` or `wrong` is noted with its time; a piece already in that state in the first snapshot is not; the age grows with the clock; a new round (a new puzzle id) clears it.
- **The motion's values at given ages:** the boing's scale at 0, 75 and 150 ms (1.0, 1.12, 1.0 within 0.01); the wobble's angle at 0, 30, 60, 90 and 120 ms. With effects off, all of them are still.
- **Pixels**, rendered to an image as the look's tests do (RepaintBoundary and `toImage`), in Sunny and in Night:
  - the board's middle is the `board` token, the tray's middle the `tray` token, and the field's corner outside the board the `background` token;
  - an Easy target's faint fill is near its piece's colour at 0.25 over the board;
  - a locked piece's middle is near its piece colour (shading allowed: within the fallback's highlight and shade).
- **HUD:** the warning clock's pill is `bad` and the text ink. The text measure test, rule 5.
- **Layers:** `tools/review.sh` finds no `layers` FAIL. camera.dart and the rules files don't import toy_look.
- All existing tests pass (puzzle, host, phone, tv). Fix only colour pins, and list each in the report.

in the report: test counts before and after (puzzle, look, host, phone, tv); the files changed; the colour grep; the new `_glyphEm` with the measured widths; the pinned colours changed; anything in section 5's Shape Race bullet not done, and why.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s4a-shape-race-look-report.md · docs/design/m12-mirror-169.png · docs/design/m12-mirror-iphone-stick.png · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-stick.png · packages/puzzle_game · packages/toy_look · packages/party_host/test · controller_app/test · tv_test_app/test
check: format analyze look puzzle host phone tv
report: docs/briefs/m13/s4a-shape-race-look-report.md
