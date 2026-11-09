# M13 review R1: the look and the games

Read-only pass over `git diff d06f88a..HEAD -- packages/toy_look packages/puzzle_game packages/test_game
packages/game_kit`, lib and tests, against review-rules A to D, coding-guidelines, design/look-and-sound (all sections)
and PRD-v2 L1-L6, T15, G1-G8. Only this report was written. Checks: `flutter test` toy_look 109 passed, puzzle_game 171,
test_game 62; `flutter analyze` clean in the three; `dart format --set-exit-if-changed` 0 changed in the four packages;
`bash tools/review.sh --base d06f88a` 2 fail, 151 note (both FAILs below).

## Findings

- **must** · `test_game/lib/src/arena_hud_widgets.dart:132` · coding-guidelines, functions under 60 lines · `_PlayerRow.build`
  is 69 lines, the only function over 60 in the range (review.sh FAIL below); split the avatar, the name line and the cell.
- **should** · `toy_look/lib/src/toy_shape.dart:104` · B6, design 6 · a new `FragmentShader` per shape per frame, none
  disposed (~20 a frame with 9 pieces and 4 workers), never measured on a device; `toy_background.dart:216-224` keeps one
  and sets its uniforms before each `Paint`, so one of the two comments on when uniforms are read is wrong, and
  `toy_shape.dart:64-66`'s reason would make the sky wrong if it were true.
- **should** · `puzzle_game/lib/src/view.dart:54,60,148,150` · design 7 line 181, B2 · the moments are aged on a local
  `Stopwatch()` that never stops: pause right after a drop and resume, and the ✓ sparkle is gone and the boing skipped,
  the pause counted as animation time; two screens fed the same frames start the same boing a network gap apart. The
  call flash already ages from `s.timeLeftMs` (`puzzle_painter.dart:296`) and the arena from `roundTimeS`.
- **should** · `test_game/lib/src/arena_view_widgets.dart:17,39` · C (a wiring mistake made silent) · `defaultArenaLook`
  draws a Sunny phone board when a screen lost its `ToyLookScope`; no app and no test reads it (tests use `withLook`), and
  its doc's reason is false: game_kit's frame tests mount `FakeView` and game_kit has no scope.
- **should** · `puzzle_game/lib/src/puzzle_painter.dart:199-208` · T15 hint glow · drawn (focus fill at 0.5, 2.5 px blur,
  1.5× focus edge) but no test paints a hint; nothing fails if the glow is dropped.
- **should** · `puzzle_painter.dart:226` and `arena_painter.dart:234` · no duplicated code · each game keeps a private dash
  helper while toy_look exports `paintDashedEdge` (`toy_dash.dart`, `on`/`off` shares): three copies of one rule.
- **should** · `puzzle_game/lib/src/match_hud.dart:6,33,39,43,47,52,88,98` · §2 magic numbers · 3.2, 4.2, 5.4, 10, 150,
  0.4, 0.8 unnamed where toy_look names its own; most of review.sh's 151 notes are such literals.
- **later** · `puzzle_painter.dart:329-338` · B6 · `_insideOpenTarget` rebuilds the locked set per call, is called per locked
  piece and builds a `Path` per open target: O(pieces³) paths a frame, fine at 9 and a trap as the set grows.
- **later** · `mirror_painter.dart:123,171` · B6 · `_pxPerUnit(canvas)` (a `getTransform`) per target and per player though
  `paint` already holds it as `px` at line 75.
- **later** · `shaders/toy_shade.frag:49-52` against `body_fallback.dart:39,46` · design 6 ("the fallback must look the
  same") · the glint is 8 %×5 % of the bounds in the fallback and a radius of about 0.16 in the shader's −1..1 box (a 16 %
  ×9.4 % extent with the 1.7 stretch), twice the size, at alpha 0.9 against 0.75; the highlight and shade do match.
- **later** · `test_game/test/arena_character_test.dart:111` · "a test that would still pass if its rule broke" ·
  `greaterThan(0)` ink above the marble passes for any accessory, so the wrong one still passes; toy_look's own test
  holds the six silhouettes to ≤70 % shared and nothing pins `ToyCharacter.forPlayer` in the arena.
- **later** · `arena_painter.dart:106` · C, look-and-sound row · the mat's dot colour comes from
  `look.palette == ToyPalette.sunny` where every other colour is a token; `puzzle_painter.dart:340-346` has two `_mark`
  doc comments, the first stale.
- **later** · `view.dart:110-135` (with `party_host/lib/src/ui/puzzle_screen.dart:256`) · B5 · the worker's 7 mm floor
  applies only where `pxPerMm` is the drawing phone's (on STATUS's step-9 list; the phone's own views are r3's).
- **later** · the games' painters · design 152 binds reduce-motion to the sky only · a device asking for reduced motion
  still gets the boings, blinks, sparkle and the arena's goal pulse; the games follow `look.effects` alone. Question 1.

## Combination table (A3)

| State | Verdict |
| --- | --- |
| Sunny and Night · effects on · no shader · TV 960×540 and 1280×720 | tested by look_paint_test "the board, the tray and the sky are the look's tokens in Sunny/Night", arena_paint_test's colour tests, toy_shape_test, body_fallback_test, toy_background_test's night dots, contrast_test both palettes |
| either · effects on · **shader loaded** · TV or phone | **not tested**: no shader loads under `flutter test` (toy_shaders_test says so). The body is `toy_shade` clipped to the path, the sky one rectangle of `toy_backdrop`; Claude's Windows check only (step 6) |
| either · **effects off** · no shader · either | tested by body_fallback_test (bands, glint), toy_background_test "with the effects off the sky stays still", piece_moments_test and worker_moments_test with `effects: false`, arena_paint_test "the goal glow pulses with effects on and is still with them off" and "a recovering marble fades with effects on and is still with them off" |
| either · either · either · **reduce motion on** | the sky holds still (toy_background_test "with reduced motion asked for the sky stays still"), ToyButton and ToyCard stop (their tests); the games' painters ignore it — **not tested**, the reduce-motion finding |
| either · either · either · **phone, short box** | tested by view_test "a phone draws one side, or the whole match, at both phone sizes", "the layout is the same in a box smaller than a 1280 x 720 window and at TV size, apart from scale"; arena_hud_test "the bar folds to one line on a phone box". Sizes stay look px because they are divided by `_pxPerUnit`; the 7 mm floor needs a real `pxPerMm` (the 7 mm finding) |
| a still sky in a round against a drifting menu; a new look on the same painter | tested by toy_background_test "under a ToyStillSky above it the sky stays still" and "a ToyStillSky under the sky holds it; removing the last hold starts the drift"; the games' `shouldRepaint` compares the look (`match_painter.dart:339`) but **no test** paints one board twice in two looks |

## Part A, job by job

1. **Every host setup.** The painters read the box and the look only; TV 960×540, 1280×720 and both phone sizes are tested (table), and nothing new crosses the wire, so an older peer draws the same picture.
2. **Kept state.** The moments live in the view's `State`, fed per snapshot and over after their window (the clock finding); the sky's holds count and release with an assert (tested); the shaders load once, never disposed (design 6).
3. **Combinations.** The table. 4. **The folder.** Only this report was written. 5. **Overstep.** Nothing stopped.

| Job | Its self-check | True? |
| --- | --- | --- |
| 1 spike | shader works on Windows and Android, light and shadow fixed | yes as read (the device runs can't be repeated here) |
| 2a tokens | look 50, every check green, boundary check on lib only, 120 columns | yes: contrast_test holds both palettes to 4.5:1 text and 3:1 switch; review.sh's boundary check is a filename whitelist for `toy_look` imports, so "a rules file imports painting or material" (design 7) has no test |
| 2b widgets | look 74 | yes (now 109): ToyButton, ToyCard, ToyBackground each have effects-off and reduce-motion tests |
| 4a Shape Race | puzzle 144; flat mat, ✓/✗ strokes, sizes from the whole canvas scale, clocks at midday | yes; the one size not from the look is the call flash's `1.6` world units (`puzzle_painter.dart:319`) |
| 4b the worker | puzzle 170 | yes; the 7 mm test runs for the phones camera only (the 7 mm finding) |
| 4c characters | look 94, host 203 | yes for the worker, marble and badges; the arena's accessory test is the weak one (the accessory finding) |
| 5 the Arena | arena 60 | yes (now 62); the mat's palette branch is the mat finding |
| 6 shaders | look 108, arena 62, host 206, phone 405, tv 51; the shader and fallback skies match | counts hold (look 109, arena 62); the sky's picture tests are the Canvas fill, so the match is a device check, not a test |

## Part C, weighed against M14 (PRD-v2 G1-G8)

The one item that costs more later is the one M14 reuses: the moments' clock. M14's pop-ups, best times and the cat must be drawn from the frame the host sent (G1-G3), and moments aged by a local `Stopwatch` phase-shift every future effect per screen and stretch it over a pause, in three call sites. The shader per draw and `defaultArenaLook` are cheap now and later, but the silent fallback is harder to see once M14 adds screens over the same viewer. C row 2 is clean.

## PRD coverage

- **L1** (one place, both palettes, Auto by hour): done — tokens in `toy_colors.dart`, `LookChoice`/`paletteFor` (Sunny
  7:00-18:59) tested in `look_choice_test`, every painter takes the look (D5). The palette mid-round rule is r2's.
- **L2** (Shape Race and the Arena in the look, TV, phone, mirror): done at the picture level — board, tray, targets,
  pieces, HUD (look_paint_test), workers (worker_paint_test), the arena's mat, walls, bumpers, goal, glow, marbles
  (arena_paint_test, arena_character_test), bar and banner (arena_hud_test). Open: the 7 mm floor; mirror_test checks the
  mirror's frame and its dot, not the pieces it draws.
- **L4** (two shaders with Canvas fallbacks, the effects setting): done in code — loaded once and warmed behind the start
  screen (`toy_shaders.dart`), a fallback per shape and per sky, the setting decides; not proven on a device, and the
  shader path has no test.
- **L6** (characters, not numbers): done — `ToyCharacter.forPlayer` (colour slot plus accessory) in toy_look, worn by the
  worker and the marble, and on the badges (r2, r3); the tests pin the look's six silhouettes, not the choice.
- **T15 warning**: done — the last 15 s puts the clock on a `bad` pill with the time bar red (look_paint_test "the
  warning clock sits on a bad pill, its text ink", view_test "the HUD's time bar is green ... red while it warns").
- **T15 hint glow**: in the look and untested (the hint glow finding); the delay setting and `hintTargets` are the
  rules', tested in rules_test "the hint glow comes after holding the same piece for a while".

## review.sh

```
FAIL func     packages/test_game/lib/src/arena_hud_widgets.dart:132 69 lines (>60): Widget build(BuildContext context)
FAIL color    tv_test_app/lib/src/ui/shader_spike_rows.dart:117 a colour outside toy_look
review: 2 fail, 151 note
```

The colour FAIL is `tv_test_app`'s spike screen, outside this pass's area: r3's.

## Not checked

- Nothing on a device: no shader loads under `flutter test`, so the shader path, effects on and off in the shader, the
  hint glow's look and the sky on a TV box are unverified here.
- `packages/game_kit` has no diff in the range; its 48 tests were not run (the three suites above were). The apps and
  party_host's screens are r2 and r3, as are the worker's tongue/determined/"o" faces (step-9 polish).

## Questions

1. Should the games' motion stop when the device asks for reduced motion, or is the effects setting enough (design 152 binds reduce-motion to the sky only)?
2. Is the per-draw `FragmentShader` in `toy_shape.dart` needed, or can a shape take the sky's single shader (the two comments contradict, and the frame cost was never measured)?
3. Which glint is the intended one, the shader's twice-size one or the fallback's 8 % by 5 %?
4. Can the moments age from a snapshot clock (the arena's `roundTimeS`, or `-timeLeftMs` for a puzzle), or is the local `Stopwatch` deliberate?
5. Should `defaultArenaLook` go, so a screen that lost its `ToyLookScope` throws as the puzzle's views do?

## Commit message

```
M13 review r1: the look and the games

- Read d06f88a..HEAD for toy_look, the puzzle and arena painters and views, and game_kit. No fixes.
- 1 must (a 69-line build), 6 shoulds, 7 later, 5 questions in the report; the host is r2.
```

## Status row

Step 9 review r1 (look and games, read-only): done, 1 must + 6 should + 7 later + 5 questions in the report; open: r2
and r3, the must and should fixes, then the Windows and device checks.

## Delete

- none
