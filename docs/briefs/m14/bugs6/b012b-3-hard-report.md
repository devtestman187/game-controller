# M14 bugs6 b012b-3-hard — six Hard puzzles (phase 3 of 3)

## Summary
The library now has a Hard level: six new puzzles, each 10–12 pieces with 3–4 big,
every non-circle shape turned, and at most 2 repeated shape pairs.

| id | pieces | turned | big | pairs | file |
| --- | --- | --- | --- | --- | --- |
| dragon | 11 | 11 | 3 | 2 | `packages/puzzle_game/puzzles/dragon.json` |
| windmill | 11 | 9 | 3 | 2 | `packages/puzzle_game/puzzles/windmill.json` |
| lighthouse | 11 | 10 | 3 | 1 | `packages/puzzle_game/puzzles/lighthouse.json` |
| dinosaur | 10 | 10 | 3 | 1 | `packages/puzzle_game/puzzles/dinosaur.json` |
| tractor | 11 | 8 | 3 | 2 | `packages/puzzle_game/puzzles/tractor.json` |
| tower | 11 | 8 | 3 | 2 | `packages/puzzle_game/puzzles/tower.json` |

All six are registered in `puzzles/index.json` after `butterfly`, in that order, and each
passes `checkPuzzle` (test/puzzle_check_test.dart) and the schema (puzzle_schema_test.dart).
The brief's pictures, solved and start, in `docs/briefs/m14/bugs6/b012b-3-hard/`:

- dragon-solved.png, dragon-start.png
- windmill-solved.png, windmill-start.png
- lighthouse-solved.png, lighthouse-start.png
- dinosaur-solved.png, dinosaur-start.png
- tractor-solved.png, tractor-start.png
- tower-solved.png, tower-start.png

Design sheets for the same six were re-rendered into `docs/design/puzzles/`.
Tests: new `test/hard_library_test.dart` reads the Hard rules from the files and fails before
the puzzles existed; `library_test` expects six at each level and the Hard id order; the
`rules_test` index pin and `puzzle_new_test`'s insert-after-last-of-level case cover Hard;
host gains a picker test that the library offers the Hard card and its six puzzle keys,
`puzzle_continue_test` ends at Hard, and the Best-times tests scroll to the now-lazy button.

## Files changed
- `docs/briefs/m14/bugs6/b012b-3-hard-report.md` — this report.
- `docs/briefs/m14/bugs6/b012b-3-hard/{dragon,windmill,lighthouse,dinosaur,tractor,tower}-{solved,start}.png` — 12 pictures at 640×360.
- `docs/design/puzzles/{dragon,windmill,lighthouse,dinosaur,tractor,tower}.png` — the six design sheets.
- `packages/puzzle_game/puzzles/index.json` — the six new ids after `butterfly`.
- `packages/puzzle_game/puzzles/<id>.json` — the six new puzzle files.
- `packages/puzzle_game/test/hard_library_test.dart` — new: the Hard rules, read from the library.
- `packages/puzzle_game/test/library_test.dart` — six per level, the Hard id order.
- `packages/puzzle_game/test/rules_test.dart` — the index pin lists the six Hard ids.
- `packages/puzzle_game/test/puzzle_new_test.dart` — a new Medium lands after `butterfly`, a new Hard after the last id.
- `packages/party_host/test/games_screen_levels_test.dart` — the Hard card and its six puzzle keys, from the files.
- `packages/party_host/test/support/host_harness.dart` — `openBestTimes` scrolls the button into view.
- `packages/party_host/test/best_times_screen_test.dart` — uses `openBestTimes`; dropped the now-unused material import.
- `packages/party_host/test/controller_menus_test.dart` — the D-pad walk to Best times stops once the button is focused or built.
- `packages/party_host/test/puzzle_continue_test.dart` — Medium is followed by Hard, and Hard is last.
- `packages/puzzle_game/test/tmp_brief_png.dart`, `tmp_hard_measure.dart` — the brief pictures and the measurements; deleted after this job.

## Self-check (review rules A1–5)
1. Host setups: not affected — the change is content plus tests; every host draws a puzzle from the same snapshot. Puzzle view tests (`puzzle_render_test`, `puzzle_check_test`) and all host and phone tests pass.
2. Kept state: none added — the level card and its puzzle list are derived from `index.json` on each build (`games_screen_levels_test`).
3. New state combinations: none — no round, timer, pause or wait changed; the level list only gained an entry, and `puzzle_continue_test` shows the next level after Hard is none.
4. Stay in the job's folder: every write is in the allow list (files above); no other file was touched.
5. Stop rather than overstep: `tools/level.sh new/check/render` cannot run in this sandbox, so the puzzle files and pictures were made by hand and the script's tests run instead; the stale Hard line in `docs/levels.md` is outside the allow list and is Question 1.

## Computed test values
Measured by a temporary test on the files (smallest piece at the narrowest safe phone area,
`Size(640, 356)`, seeds 1–21, both sides; span and split scale from the home layout):

| id | smallest piece | mm | span w×h | split scale |
| --- | --- | --- | --- | --- |
| dragon | horn, 14.00 units | 10.08 | 88% × 65% | 0.96 |
| windmill | door, 15.81 units | 9.56 | 73% × 86% | 0.94 |
| lighthouse | gallery, 15.65 units | 8.76 | 86% × 94% | 0.87 |
| dinosaur | plate front, 14.00 units | 11.07 | 78% × 56% | 1.07 |
| tractor | small wheel, 15.00 units | 9.37 | 83% × 82% | 0.95 |
| tower | window left, 15.00 units | 8.88 | 61% × 89% | 0.92 |

All are above the 8.5 mm floor and the 0.85 split minimum; `checkPuzzle` is empty for every one.

## Decisions
- `tools/level.sh` is blocked in this sandbox, so the six files were written by hand and its
  checks run through `test/puzzle_check_test.dart`, `puzzle_schema_test.dart` and
  `twins_library_test.dart`.
- No circle was used as an eye or a small dot: a circle's box is its diameter, and the 8.5 mm
  floor needs the small pieces near 8 units. Shape sizes were tuned at the tray instead.
- Pink `#E91E63` and teal `#00897B` were used where the palette tokens (silver, steel, sky)
  fall within 0.08 of each other, so differently-shaped neighbours keep their colour hint.
- Every piece fits the 54×72 tray at the 200 start seeds; the tractor's bumper and the tower's
  bush were dropped to keep the tray clear (both puzzles stay at 11 pieces).
- `library_test`'s case was renamed to say what it now checks (six at each level).
- The Best-times button is now lazily unbuilt below three level cards, so the tests scroll to
  it through one `openBestTimes` helper rather than `tapVisible`.

## Questions and suggestions
1. `docs/levels.md` still says the library has no Hard puzzle. It is outside the allow list;
   it needs a one-line follow-up edit.
2. Old saved best times are untouched, so the six new puzzles start with empty boards — is
   that the intent for the milestone?
3. The design sheets in `docs/design/puzzles/` were re-rendered for every new puzzle, as the
   earlier sets do. Say if those are not wanted in the repo.

## Commit message
Add six Hard puzzles and a Hard level in the picker

The library gains its Hard tier: dragon, windmill, lighthouse, dinosaur,
tractor and tower, each 10-12 pieces with 3-4 big, every non-circle
turned, and at most two repeated shape pairs. They sit in index.json
after butterfly and pass the rule book.
The library test now counts six at each level, and a new hard_library_test
reads the Hard rules from the files. A host test shows the Hard card with
its six puzzles; best-times tests scroll to the button below three cards.

## Status row
Hard puzzles: the six are in the library, the picker and the reports — done; `docs/levels.md`'s old "no Hard puzzle" line and the new best-times boards are open.

## Delete
- packages/puzzle_game/test/tmp_brief_png.dart
- packages/puzzle_game/test/tmp_hard_measure.dart

