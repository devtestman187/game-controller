# M13 5: the Arena in the look

The Arena is drawn in the look now — a dotted `field` mat, toy-block walls, red bumpers, a `good` goal pad with a
checkered flag and a soft glow, a paper start pad, glossy marbles with two eyes that look the way they last moved,
and a HUD and banner in the look — on the host and on a joined phone alike, since both draw through
`ArenaField`/`ArenaPainter`. The marbles are the toon shader's first real use: `toyShape` with `look.shade`, and the
Canvas fallback when the look has no shaders. The eyes are worked out by a new rules-side `ArenaMoments` from the
snapshots alone (a still marble keeps its last direction, a new round starts right again), so nothing was added to a
snapshot or the protocol. One rule of the brief could not be kept as written — the `ToyPill` does not fit a phone's
pinned one-line bar — and is question 1.

## What changed

### packages/test_game/lib/src

- `arena_painter.dart` (rewritten, 242 lines): `ArenaPainter(s, roster, look:, moments:)`. It fills the box with
  `field`; draws the mat, the start pad, the goal with its glow and its flag, the walls and the bumpers; then hands the
  marbles to `ArenaMarblePainter`. One `ToyShapeStyle` is built in `paint` and passed to everything that draws a
  shape. Positions are fractions of the field and sizes fractions of its shorter side, as before, so the same
  snapshot draws the same arena at any size; the painter draws in px and its canvas is never scaled, so the look's
  pixel sizes are used as they are (rule 5).
  - **The mat:** the old grid's points, `ink` at 0.12 in Sunny and `onBackground` at the look's `dotAlpha` in Night,
    as one `drawPoints` call (round caps make each point a dot) rather than 153 `drawCircle`s a frame.
  - **The walls:** `wall` blocks with `cardCorner`-ish corners (0.012 of the shorter side), the look's hard shadow
    (`style.shadowOffset`, `style.shadowAlpha`), an ink edge, and a top band `Color.lerp(wall, paper, 0.3)`, clipped
    to the block and at most 0.4 of its height so a tall block is not half band. Flat, never `toyShape`d (4a's
    review: shaded panels read as cushions).
  - **The bumpers:** a `toyShape` disc in `bad` (so the shader lights it, or the fallback) with the look's ink edge
    and a `paper` ring at 0.55 of its radius.
  - **The goal:** a `good` rounded pad (radius `ToySizes.cardCorner`), a deflated ink edge, a blurred `good` glow
    that reaches 0.03 of the shorter side, and the flag: an ink pole at the pad's top-right with a 3 × 2 cloth of
    `paper` and `ink` checks and an ink frame. The word `GOAL` is gone (its `TextPainter` with it).
  - **The start pad:** a `paper` disc at 0.5 alpha, its ink edge dashed by extracting `PathMetric`s.
- `arena_marble_painter.dart` (new, 185 lines): the marbles, in one place so `arena_painter.dart` stays readable.
  Each is a `toyShape` disc in `player(n)` (`player(1)` for a player with no roster entry) with `look.shade`, two
  eyes (paper whites with an ink edge and an ink pupil, both shifted 0.18 of the radius the way the marble last
  moved, the pupil 0.08 more), the player's number on its lower half in `look.type.title` in ink (only when the
  roster has more than one player, as M12 did), a `focus` glow at 0.35 while dashing, a `focus` arc inside an ink arc
  for the dash cooldown and the aim cursor (a ring and a cross, the player's colour inside an ink edge). A recovering
  marble is drawn inside one `saveLayer` whose paint carries `recoveringAlpha(roundTimeS)`, so its body, its eyes and
  its number fade together instead of blinking at 5 Hz.
- `arena_moments.dart` (new, 85 lines): `ArenaMoments` (each player's last direction of travel, a new round clearing
  it, a first sighting of an id inside a round clearing that player's, a travel under `stillShare` = 0.0005 of the
  field not counted as a move since a snapshot rounds to a ten-thousandth), `lookRight`, and the recovering fade:
  `recoverPulseHz` 2.5, full 1.0, faint 0.4, `recoverStillAlpha` 0.7 (the middle, for effects off) and
  `recoveringAlpha`. `dart:ui` for `Offset` only: no Flutter, no toy_look.
- `arena_view_widgets.dart` (144 lines, was 263): `ArenaBoard` resolves the scope with
  `dependOnInheritedWidgetOfExactType` and wraps its subtree in a `ToyLookScope` (a board drawn with no scope at all —
  `game_kit`'s `frame_view_test` mounts a module's viewer on its own — draws in `defaultArenaLook`, Sunny on a
  phone); `ArenaField` is a `StatefulWidget` keeping one `ArenaMoments`, noted in `initState` and in `didUpdateWidget`
  when the snapshot is not the same object; the winner's banner is a `ToyCard` headed in the winner's colour, or in
  `good` when there is no winner.
- `arena_hud_widgets.dart` (new, 182 lines): the bar, split out of `arena_view_widgets.dart` when that file passed
  the guidelines' 300 lines ("split along a responsibility seam, as part of the same job"). It is a `paper` strip
  with its ink line drawn as a `foregroundDecoration` border, so the line costs the bar no height and the pinned
  phone heights hold; every text is ink; the colour dot is `player(n)`; a ready dash is a `ToyPill` in `good` on a
  tall box and the same words in ink on a phone's one-line bar (question 1).
- `test_game.dart`: exports `arena_hud_widgets`, `arena_moments` and `arena_view_widgets` (the tests mount
  `ArenaBoard`/`ArenaField` directly). `arena_roster` too.

### packages/test_game/pubspec.yaml

- `toy_look: {path: ../toy_look}` after `protocol` (rule 1). `flutter pub get` ran at the repository root.

### packages/test_game/test

- `support/look.dart` (new, 18 lines): `sunny`, `night`, `sunnyStill` (effects off) and `withLook(child, {look})`, the
  `ToyLookScope` helper every view test uses (rule 1). `support/look_fonts.dart` (new, 29 lines): `loadLookFonts`,
  copied from `puzzle_game`'s, so the pixel tests draw the numbers in the real Fredoka.
- `support/frames.dart` (new, 19 lines): `pixel(bytes, width, x, y)` (0xRRGGBB out of a frame's raw RGBA) and
  `colourGap(a, b)` (the largest gap in a channel), the two readers the pixel tests use.
- `arena_moments_test.dart` (new, 104 lines, 6 tests): right at the start; the eyes follow the last move (right, down,
  and 53° down-right as a unit vector); a still marble keeps its direction, with 0.0002 of rounding not a move and
  0.0011 a move; each player its own; a new round starts right and the jump back to the start pad is no move; the fade
  (full, the middle at 0.1 s, faint at 0.2 s, full at 0.4 s, 25 dips in 10 s, under 3 a second, still at the middle
  with effects off).
- `arena_paint_test.dart` (new, 256 lines, 7 tests): the field, the wall, a bumper, the goal and a marble's middle in
  Sunny and Night; the eyes' ink to the right of a marble at rest and to the left of one that moved left; the fade
  changing between two frames and not changing with effects off.
- `arena_hud_test.dart` (new, 97 lines, 4 tests): the banner's header is the winner's colour, or `good` for a lone
  player's goal; a ready dash is a `ToyPill` filled `good`; the one-line bar has no pill and keeps the words in ink.
- `arena_view_test.dart`: the two `ArenaView` pumps wrapped in `withLook`; no expectation changed.
- `_measure_test.dart` (new, 52 lines, 1 test, **scratch**): prints the bar heights below in both looks. It is in
  Delete.

## The numbers

The pixel tests draw in 960 × 540 (a TV), a marble radius of 0.05 of the shorter side — 27 px, where the game's
0.032 would be 17.3 px, too few to hold an eye and a clean middle (4b's pixel tests drew at twice the game's size
too) — one marble at (384, 324), a wall at (480, 54)–(595.2, 243), a bumper at (192, 162) and the goal at
(825.6, 205.2)–(931.2, 334.8).

| what the test samples | where | expected |
| --- | --- | --- |
| the mat away from everything | (0.35, 0.85) = (336, 459) | `field`, 1 channel |
| a dot of the mat | (270, 108) — the fifth across and the second down of a 54 px step | over 8 from `field` |
| a wall's base | (0.56, 0.4) = (537.6, 216) | `wall`, 1 channel |
| a wall's top band | (0.56, 0.132) = (537.6, 71.28), inside the band's 54–88.56 | > 10 from `wall` and lighter |
| a wall's ink edge | (538, 54) | `ink`, 30 |
| a bumper's middle | (0.2, 0.3) | `bad`, 8 |
| a bumper's ring | 0.55 of its radius left of its middle | `paper`, 30 |
| the goal's middle | (0.915, 0.5) | `good`, 2 |
| a marble's body | (384, 334.8), below the eyes and the glint | in the fallback's bands: the colour, 38 % to white, 26 % to black, 8 |
| the eyes' ink, mean x | the band x ± 0.75 r, y −0.45 r to +0.12 r | rest: > +2.7 px of the middle; moved left 0.02: < −2.7 px |
| a recovering marble at 0 s and at 0.2 s | (370.5, 337.5) | different; with effects off, the same |

The recovering fade, as `recoveringAlpha` gives it: 1.0 at 0 s, 0.7 at 0.1 s, 0.4 at 0.2 s, 1.0 at 0.4 s — a dip
every 0.4 s, 25 dips in 10 s, 2.5 changes a second against the comfort rule's 3 and M12's 5. With effects off it is
still at 0.7, the middle of the fade.

The bar the arena leaves (the arena's box less the `arena` key), measured by the scratch test:

| box | before (M12) | after, phone look | after, TV look | 15 % of the box |
| --- | --- | --- | --- | --- |
| 667×375 | 52 px | 52 px | 52 px | 56.25 |
| 852×393 | 52 px | 52 px | 52 px | 58.95 |
| 960×540 | 88 px | 107.5 px | 127 px | 81 |
| 1280×720 | 88 px | 107.5 px | 127 px | 108 |

The one-line form is unchanged: the pill is not used there (question 1). The tall form grew by two `ToyPill`s'
heights less two text lines (29.75 px against about 20 px with the phone's look, 39.5 px against about 20 px with the
TV's), so 1280×720 with the phone look now sits 0.5 px under 15 % of the height, and a TV's own look takes 23.5 % of
960×540 where M12 took 16.3 % (question 2). The field keeps 432.5 px of 540 with the phone look and 413 px with the
TV's.

## Tests, before and after

| check | before | after |
| --- | --- | --- |
| look | 88 | 88 |
| arena (test_game) | 43 | 60 (plus the scratch file's 1, deleted) |
| host | 199 | 199 |
| phone | 403 | 403 |
| tv | 50 (+1 skipped) | 50 (+1 skipped) |
| kit (also run) | 48 | 48 |
| puzzle (also run) | 170 | 170 |

The 17 new arena tests are the 6 + 7 + 4 above. `arena_test`'s 20 rules tests and `arena_view_test`'s 12 pass
unchanged, no expectation touched.

## The checks

`tools/check.sh format analyze look arena host phone tv` could not be started here (this session's sandbox accepts
`flutter` and `dart` but not `bash tools/…` — it asks for an approval that never comes), so I ran its seven commands
one at a time, in the folders it uses:

- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` → 496 files, 0
  changed.
- `dart analyze --fatal-infos` (root) → no issues.
- `flutter test` in `packages/toy_look` → 88 pass; `packages/test_game` → 61 pass (60 + the scratch);
  `packages/party_host` → 199; `controller_app` → 403; `tv_test_app` → 50 (+1 skipped).
- Also `packages/game_kit` (48) and `packages/puzzle_game` (170), since both draw the arena.

One thing to know: `git status` lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc` and `.h` and
`generated_plugins.cmake` as modified. The root `flutter pub get` rewrote them byte for byte with LF line endings
(they are generated), and `git diff --numstat` lists no change to them — the files' content is the same and nothing in
them came from this job. I did not touch them by hand and did not run any git command that changes anything.

`tools/review.sh` cannot run here either (same reason, and it needs `git diff`), so I checked its rules by hand on
the lib and test files this job adds or changes: the `layers` check finds only
`arena_painter.dart`, `arena_marble_painter.dart`, `arena_view_widgets.dart` and `arena_hud_widgets.dart` importing
`toy_look` (all four match the allowed `*painter*`, `*view*`, `*widgets*`, `*_module.dart` patterns, so no `layers`
FAIL); no file is over 400 lines (largest: `arena_painter.dart` 242) and no test file over 500 (largest:
`arena_paint_test.dart` 256); no function is over 60 lines (`_paintOne` 41, `_goal` 21, `_flag` 22, `_walls` 18,
`ArenaHud.build` 30, no test body over 20); no `print`, no `// ignore`, no TODO, no `dynamic`, no `DateTime.now()`,
no `Random()`. The numeric literals the painter and the moments file add are named constants at the top of each file.

## The colour grep (rule 7)

```
$ grep -rnE "Color\(0x|Colors\." packages/test_game/lib
(no output)
```

## Colours pinned by the old tests: changed

None. `arena_test`, `arena_snapshot_test` and `arena_session_test` needed no edit. `arena_view_test` gained a
`withLook` wrapper round its two `ArenaView` pumps and nothing else: it does not look at pixels.

## Section 5's Arena bullet: what is not done

- **The wall's top band mixes to `paper`, not to white.** The look has no white token and a `Color(0x…)` literal is
  forbidden outside `toy_look` (rule 7), so the 30 % mix goes to `paper` (`#FFF6E3`), as the worker's body already
  mixes towards it. In Sunny the band's red is 38 of 255 above the wall's, its green 31, its blue 5 (a mix to
  `#FFFFFF` would be 38, 34, 14); a white token in `toy_look` would be the faithful way (question 3).
- **The dash-ready pill is not used on a phone's one-line bar** (question 1). Its words are there, in ink.
- **A marble's number is drawn only when the roster has more than one player**, as M12 did: with one player there is
  nobody to tell apart, and the number would sit under the eyes.
- Everything else of the bullet is drawn as written.

## Questions

1. **The pill and the phone's pinned bar.** A `ToyPill` is a body line and its padding — 29.75 px on a phone — so a
   one-line bar holding one is about 62 px at 667×375, over the 56.25 px that `arena_view_test` pins ("the bar ≤ 15 %
   of the height") and over the 52 px the M12 table measured. I kept the pill on the tall bar and the same words in
   ink (`Dash ready (A)`, no colour text) on the one-line bar. If you want the pill there too, the bar's pinned
   height has to move; say which you prefer.
2. **The tall bar grew by the pills** (table above): 88 → 107.5 px with the phone look and 127 px with a TV's, 23.5 %
   of 960×540. The rule that no layout may change (rule 8) and the pill of rule 4 pull against each other; I kept the
   pill. A `ToyPill` with a size (or the bar using the look's `bodySmall`) would bring it back down — worth a
   `toy_look` change in a later step?
3. **The wall's band** mixes to `paper` for want of a white token (above). Would you add `white` to `ToyColors`?
4. **A board drawn with no `ToyLookScope`** now draws in `defaultArenaLook` (Sunny, phone) instead of throwing.
   `game_kit`'s `frame_view_test` mounts `arenaModule`'s viewer with no scope and no look, and `ToyLookScope.of`
   asserts; the board cannot reach that file (it is outside this job's `allow`). The apps still put their own scope
   above every screen, so the fallback is only for a board drawn alone. Should `ToyLookScope.of` get a default
   instead?
5. **The eyes' test measures ink, not pupils.** It takes the mean x of the eye ink (whites' edges and pupils) in a
   band over the marble's middle; it shows the eyes look right at rest and left after a leftward move (over 2.7 px
   either way), but not the pupils alone, which sit 2.2 px inside their whites. A stricter test would need the
   whites' colour back out of the same band. Is that worth it?

## Self-check (review-rules part A, 1–5)

1. **Every host setup.** The look is the only thing that changed, and it reaches the field from the scope in every
   setup: TV/PC host (`screen_fit_test` draws the Arena at 960×540 and phone boxes in both palettes, host 199 pass),
   a phone on "Play on this phone" (`controller_app` 403), a phone on "Show on this device" and a joined phone
   (`arena_view_test` "fills a small or tall window"), a build one older: nothing changed in the protocol, the
   snapshot or the rules, so an older peer draws its own arena and both still play (`arena_session_test`,
   `arena_snapshot_test` unchanged and passing).
2. **When kept state starts and ends.** `ArenaMoments` starts with the field's `State` (empty), ends when the field
   is disposed, and clears itself on a new round number and on a player's first sighting in a round; it holds two
   offsets per player id and no timer. The fade is a pure function of `roundTimeS`, so nothing runs when nothing
   draws. `arena_moments_test`: "a new round starts again, and the jump back to the start is no move", "each player
   has its own direction", "a recovering marble fades in and out 2.5 times a second".
3. **How a new state combines with the others.** Nothing here pauses, hides, waits or blocks input: the moments only
   choose which way the eyes look, and the fade and the glow read the snapshot's own clock. A paused round (its
   snapshots stop) freezes both mid-way, which is what a still frame should show; a player away, a dropped link, the
   results and leaving change nothing in the painter. The snapshot's own flags still combine as M12 drew them: a
   marble can be dashing, recovering and cooling down at once and gets its glow, its fade and its arc
   (`arena_paint_test` "a recovering marble fades with effects on and is still with them off"); a recovering marble
   also keeps its eyes and its number, since they sit inside the same layer. Not tested: a round paused for a long
   time and then resumed — the fade jumps to the new `roundTimeS` (one frame's phase; `arena_session_test` pins that
   a pause does not advance the round's clock).
4. **Stay in the job's folder.** Only files in `allow:`, all under `packages/test_game` plus this report: lib —
   `arena_painter.dart`, `arena_view_widgets.dart` (changed), `arena_hud_widgets.dart`, `arena_marble_painter.dart`,
   `arena_moments.dart` (new), `test_game.dart`; `pubspec.yaml`; test — `arena_view_test.dart` (changed),
   `arena_moments_test.dart`, `arena_paint_test.dart`, `arena_hud_test.dart`, `_measure_test.dart` (new, scratch) and
   `support/look.dart`, `support/look_fonts.dart`, `support/frames.dart` (new). No file outside it.
5. **Stop rather than overstep.** Not stopped; but rule 4's pill and the pinned phone bar contradict each other (I
   chose the pinned height and said so, question 1), and `Color.lerp` towards white has no token (question 3).
   `docs/briefs/m13/STATUS.md` was not touched: the status row is below for you to paste.

## Commit message

M13 5: the Arena drawn in the toy look

The field is a dotted mat, the walls toy blocks with a lighter top band, the bumpers red toyShape discs, the goal a
good pad with a blurred glow that pulses 0.25-0.45 over 2 s (still 0.35 with effects off), a checkered flag and no
GOAL word, and the start pad paper at half alpha with a dashed edge. The marbles go through toyShape with the look's
shade, with two eyes, their number in ink on the lower half, a focus glow while dashing, a focus cooldown arc and an
aim cursor, and a recovering one fades 2.5 times a second instead of blinking at 5 Hz. A rules-side ArenaMoments
turns the snapshots into each marble's last direction, so the eyes look the way it went and a new round looks right
again; nothing was added to a snapshot or the protocol. The HUD is a paper strip with an ink line, ink text, the
player's colour dot and a ToyPill for a ready dash, and the winner's banner is a ToyCard headed in the winner's
colour.

## Status row

M13 5: the Arena is drawn in the look on the host and on a joined phone — a dotted field mat, two-tone toy-block walls, red bumpers, a good goal pad with a pulsing glow and a checkered flag (no GOAL word), a paper start pad, glossy marbles with eyes that follow the last move from a new rules-side ArenaMoments, a 2.5 Hz recovering fade, a focus cooldown arc and an aim cursor, and a HUD and banner in the look (paper strip, ink text, ToyPill for a ready dash, ToyCard banner); 17 new tests, arena 43 → 60, every check green; open: the ToyPill does not fit a phone's pinned one-line bar (same words in ink there, question 1), the tall bar grows by two pills (88 → 107.5 px, 127 on a TV's look, question 2), the wall's top band mixes to paper for want of a white token (question 3), and a board drawn with no look scope falls back to Sunny (question 4).

## Delete

- packages/test_game/test/_measure_test.dart

## Claude's review (Nov 8, 2026)

Accepted, with one change (test-first), after Claude rendered the Arena at TV size in both palettes:

- **The "dash ready" pill grew the HUD bar** from 88 to 107.5 px, 127 px on a TV and about a quarter of the screen (question 2). A ready dash is now a `good` dot with an ink edge beside the ink words, as the TV home's statuses are, on both the tall and the one-line bar.
  - Tests: the dot's colour and edge in both palettes and at both sizes.
  - A second test checks that a ready dash leaves the bar as tall as a cooling one. It was 107.5 against 88.

Answers to the questions:
1. **The pill on the phone's bar**: no pill anywhere now; the dot is on both bars.
2. **The tall bar's growth**: fixed as above.
3. **A white token**: no. Mixing the wall's band towards `paper` is right; the look has no pure white.
4. **`defaultArenaLook` when there's no scope**: keep it for a board drawn alone. The apps always put a scope above.
5. **The eyes' test**: good enough.

The marble's number goes in 4c, where each player gets a colour and an accessory (design 5b).
