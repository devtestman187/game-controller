job: M13 step 5: the Arena drawn in the toy look, the first place the toon shader is used: glossy marbles with eyes, toy-block walls, red bumpers, a goal pad with a checkered flag, a dotted play mat, and its HUD and banner in the look
pub: yes
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D1, D5, D8, D12), 3, 4, 5 (the Arena bullet) and 6 · docs/design/look-mockups.html (the Arena frame: its SVG code is the drawing to follow) · docs/briefs/m13/s4a-shape-race-look-report.md and s4b-worker-report.md (and Claude's reviews at their ends: the canvas's whole scale, flat panels, marks drawn rather than glyphs, real fonts in pixel tests) · packages/toy_look/lib · packages/test_game/lib/src (all of it) · packages/test_game/test · packages/party_host/lib/src/ui/game_screen.dart · tools/review.sh (the `layers` check) · docs/review-rules.md · docs/coding-guidelines.md

The Arena is still drawn in M12's dark colours with plain discs. This job draws it in the look, on the host and on a joined phone alike, since both draw through `ArenaField`/`ArenaPainter`. Owner, Nov 8, 2026: "Keep eyes on the marbles."

Claude's rules:
1. **The look reaches the painter.**
   - test_game depends on toy_look (a path dependency).
   - `ArenaField` reads `ToyLookScope.of(context)` and hands the look to `ArenaPainter`. Only files the `layers` check allows import toy_look (arena_painter.dart, arena_view.dart, arena_view_widgets.dart); arena.dart and the rules don't.
   - Tests put a `ToyLookScope` above the view, through a helper in test/support.
2. **What each thing becomes** (design section 5's Arena bullet):
   - **The field:** a `field` play mat. The faint grid becomes a dotted mat: small `ink` dots at the grid's points, at 0.12 alpha in Sunny and the look's `dotAlpha` share of `onBackground` at night, so they read on both.
   - **Walls:** toy blocks in `wall`, two-tone: a lighter top band (the wall colour mixed 30 % towards white) over the base. Each has the ink edge and the look's hard shadow. Flat, not shaded: 4a's review found shaded panels read as cushions.
   - **Hazards:** red bumpers, a `toyShape` disc in `bad` with a `paper` ring inside and the ink edge.
   - **The goal:**
     - a `good` pad with the ink edge and `cardCorner` corners;
     - a small checkered flag in ink and paper on an ink pole at its top-right corner;
     - a soft glow round it in `good`, which pulses gently (0.25 to 0.45 alpha over 2 s) with effects on and is still at 0.35 with effects off.
     - The word GOAL goes, since the flag says it.
   - **The start pad:** a `paper` disc at 0.5 alpha with a dashed ink edge.
   - **Marbles:**
     - a glossy `toyShape` disc in `player(n)` with `look.shade`, the shader's first use;
     - two eyes (paper whites with ink pupils) that look in the direction the marble last moved, worked out from the snapshots;
     - the player's number on its lower half in ink, in the look's title family, as on the worker, so players tell each other apart without colour;
     - a player with no roster entry is `player(1)`.
   - **Dashing:** a `focus` glow round the marble at 0.35 alpha.
   - **Recovering:** the marble fades to 0.4 alpha and back, about 2.5 times a second, in place of today's 5 Hz on/off blink. That keeps it under 3 changes a second (design comfort rule, G5).
   - **The dash cooldown ring:** a `focus` arc with the ink edge.
   - **The aim cursor:** the player's colour with the ink edge.
3. **Eyes from the snapshots.**
   - A small `ArenaMoments` (its own file, no Flutter or toy_look import, tested on its own) is fed each new snapshot and keeps each player's last direction of travel.
   - A marble that hasn't moved keeps looking the way it last moved; at the start it looks right.
   - The view keeps one in its `State` (it becomes stateful), as 4a's views do.
   - Nothing is added to the snapshot or the protocol.
4. **The HUD and the banner** (arena_view_widgets.dart):
   - every colour from the look: text `onBackground` on the background, ink on paper;
   - the round banner a `ToyCard`, headed in the winner's colour, or `good` when no player won;
   - the "dash ready" state a `ToyPill` in `good` rather than green text (text is never `good`, `caution` or `bad`).
   - Keep every key, text and layout.
5. **Sizes:** the Arena painter draws in pixels (no world scale), so the look's pixel sizes apply as they are. If anything draws inside a scaled canvas, use the canvas's whole scale, as 4a's `_pxPerUnit` does.
6. **Cost:** with 4 players, `paint` makes no more `TextPainter`s than today (the numbers), and one `ToyShapeStyle` per paint.
7. **Colours:** after the job, `grep -rnE "Color\(0x|Colors\." packages/test_game/lib` finds nothing. List the grep in the report.
8. Change no rule, size, speed, hazard or layout. arena_test and its rules tests pass as they are, bar colours they pinned.
9. Files under 400 lines, functions under 60; split the painter into parts if it grows.

tests (each failing first):
- **`ArenaMoments`:**
  - looks right at the start;
  - follows the last move;
  - keeps the last direction while still;
  - each player has its own direction;
  - a new round (a new round number) starts again.
- **Pixels** (RepaintBoundary and `toImage`, in the look's real fonts, as 4b's review did), Sunny and Night:
  - the field away from everything is `field`;
  - a wall's lower half is `wall` and its top band lighter;
  - a hazard's middle is `bad`;
  - the goal's middle is `good`;
  - a marble's middle is `player(1)`, with shading allowed within the fallback's highlight and shade.
- **The eyes:** a marble moving right has its pupils right of its eye centres, and moving left, left.
- **Recovering:** the marble's alpha changes at most 3 times a second; with effects off, nothing pulses.
- **HUD:** the banner's header is the winner's colour; "dash ready" is a `ToyPill` in `good`.
- **Layers:** no `layers` FAIL from tools/review.sh.
- All existing tests pass (arena, look, host, phone, tv). Fix only colour pins, and list each.

in the report: test counts before and after (arena, look, host, phone, tv); the files changed; the colour grep; the pinned colours changed; anything in section 5's Arena bullet not done, and why.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s5-arena-look-report.md · packages/test_game · packages/party_host/test · controller_app/test · tv_test_app/test
check: format analyze look arena host phone tv
report: docs/briefs/m13/s5-arena-look-report.md
