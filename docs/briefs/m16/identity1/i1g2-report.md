# i1g2 report: Shape Race workers, score bars and the Cat Chaos path

## Summary

Changed, all inside `allow:` (tests first: the worker test failed to compile on the missing
`MatchView.characters`, and the score bar test failed on slot 1's blue, RGB (0.18, 0.61, 0.94),
where the row's character is slot 5, RGB (1.00, 0.36, 0.54)):
- New `worker_identity_test.dart` (4 tests), `score_bar_identity_test.dart` (2 tests) and a new
  test in `puzzle_screen_test.dart` (11 now) for the TV's map.
- `puzzle_painter.dart` and `worker_painter.dart`: `characters` by player number, which
  `_paintWorkers` uses with `ToyCharacter.forPlayer` only as the missing entry's fallback;
  `shouldRepaint` compares it.
- `match_painter.dart`, `play_view.dart`, `puzzle_module.dart` (the frame's chars and the roster)
  and `puzzle_screen.dart` (the host's players) pass it down to the painters.
- `MatchView` moved from `view.dart` (379 lines) to `play_view.dart`: 231 and 363 lines now.
- `score_row.dart` and new `score_row_bar.dart`: the bar's fill is the row's character's colour.
- Cat Chaos draws no players — `cat_chaos.dart` is the cat's rules and used neither `forPlayer`
  nor `player(number)`, so there was nothing to fix there and the file is untouched.

Checks: `tools/mine.sh` → ok (13 formatted, 2 analyzed, 2 tested). `tools/check.sh format analyze
puzzle host` → PASS format, PASS analyze, PASS puzzle (449 tests), PASS host (102 s).
`tools/review.sh` → 0 fail, 7 note (all pre-existing size and function notes).

Line counts, all under 380: play_view 363, puzzle_painter 357, puzzle_screen 379, match_painter
235, worker_painter 340, puzzle_module 180, view 231, score_row 347, score_row_parts 75,
score_row_bar 52; the new tests are 136 and 86.

## Self-check (review-rules part A)

I did not open docs/review-rules.md in this job; these are what I checked, not its text.
1. Host setups: TV host with a local p1 and a phone p2 wearing a crown (`puzzle_screen_test`), a
   phone-host screen (same screen, `PuzzlePlayView` path), a joined phone drawing the viewer
   (`worker_identity_test`, roster + `characters`), and a host that sent no pick (the worker
   tests draw a map without player 1 / an empty map → number default).
2. Kept state: none is new. `characters` is a value rebuilt each build from the host's players or
   the frame; nothing starts, ends or runs when nothing is going on (no timer, no listener).
3. Combining: the value is data only, so the pause menu, host away, player away, "Get ready", a
   dropped link, the results and leaving change nothing about it; a frame without a pick keeps
   the number's default.
4. Files: only the brief's `allow:` list was edited (see `git status`; the modified PNGs and
   `docs/briefs/m16/identity1/run.log` are the tools' known churn, not mine).
5. Stop rather than overstep: `view.dart` was 379 lines and could not grow. Its natural block to
   move (the ✓/✗ marks) belongs in `slot_paint.dart`, which is not in `allow:`, so I moved
   `MatchView` into `play_view.dart`, beside the play view that builds it.
6. Every look: the worker tests draw the menu look and `ToyLook.build(tv: true)`;
   `score_bar_identity_test` runs both looks through `forEachLook` / `pumpHostLook`. No fixed
   pixel height was added to a look-sized widget.

## Decisions

- `MatchView` in `play_view.dart` (above): `view.dart` had 379 lines and the addition is 7 lines.
  `puzzle_module.dart` now imports `play_view.dart`; the package export is unchanged, so every
  test and app that named `MatchView` still finds it.
- The bar widget moved to `score_row_bar.dart` rather than growing `score_row_parts.dart` (the
  brief lists that file): the bar is the one row part that takes a character.
- `puzzle_module` fills a character for every roster entry (`ToyCharacter.of`), so a player with
  no pick is in the map with the default; the painter's missing-entry fallback still covers a
  player outside the roster.
- `PuzzleView` got no `characters`: the brief names `MatchView` / `PuzzlePlayView`, and
  `PuzzleView` is drawn only by tests and pictures, where the default is what they expect.
- The other side's mirror (`mirror_painter.dart`, not in `allow:`) still draws its dots in
  player 2's colour by design; it draws dots, not workers.

## Values computed for the expectations

- Score bar: before the fix the menu-look fill read RGB (0.1804, 0.6078, 0.9412) = slot 1; the
  test wants slot 5 (1.0000, 0.3608, 0.5412) for the chosen crown, in both looks.
- Worker body: the middle pixel is within a colour gap of 8 of the chosen slot's colour and more
  than 40 from slot 1's; with no pick it is within 8 of slot 1's.
- Accessory: ink in a box of 0.3 body radii round the crown's top point — more than 0 with the
  crown, exactly 0 with player 1's own ears. (I printed no raw pixel counts; the assertions are
  the bounds above.)
- The body's radius in these frames is 27 image px (1.3 units × 8 px/unit at twice the 640×360
  box), so the crown's top box is about 8 px square.

## Blocked

Nothing blocked. Nothing outside `allow:` was edited.

## Questions and suggestions

1. Is `play_view.dart` the home you want for `MatchView`? It keeps `view.dart` at 231 lines, but
   the natural block to move (the ✓/✗ marks) belongs in `slot_paint.dart`, outside `allow:`.
2. `PuzzleView` (one board, drawn alone) has no `characters`: the brief named `MatchView` /
   `PuzzlePlayView`, and only tests and pictures use `PuzzleView`, so it keeps the defaults.
3. The other side's mirror (`mirror_painter.dart`, not in `allow:`) still marks its dots in
   player 2's colour. It draws dots rather than workers, so I left it; a later job could give it
   the characters if the mirror should show them too.

## Hand-over

Ready for review. No commits, no pushes, nothing staged.

## Commit message

Shape Race workers and score bars wear the players' characters

Shape Race's workers take their character from the host: the TV builds it from its own
players, a joined phone from the frame's chars and roster, and a player with no pick keeps
the default its number gives. The score card's bar is filled in the row's character's colour
instead of the number's, so a row reads as the player on every screen.

MatchView moved from view.dart to play_view.dart to keep view.dart under its size limit. Cat
Chaos draws no players, so nothing changed there.

## Status row

i1g2 done: Shape Race workers and score bars draw the chosen character (menu and TV look, TV
and joined-phone path); open: the mirror's dots and PuzzleView's pictures still use number
defaults, and Cat Chaos needed no change.

## Delete

- none
