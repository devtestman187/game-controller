# M14 bugs7 tractor-redo — two tractor proposals (B-012)

## Summary
Two Hard puzzle proposals that read as a tractor in side view, in the owner's words: a small
front wheel, a LARGE rear wheel (circles), a cab with a window, an engine bonnet and an
exhaust pipe. Nothing ships: no index line, no change to the shipped `tractor.json`.

| | pieces | big | turned (non-circles) | pairs | picture span | `checkPuzzle` |
| --- | --- | --- | --- | --- | --- | --- |
| A | 10 | 3 | 8 of 8 | 1 | 50 × 43 units, 62.5% × 59.7% | empty |
| B | 11 | 3 | 9 of 9 | 0 | 54 × 39.5 units, 67.5% × 54.9% | empty |

- **A (recommended): a classic farm tractor facing left.** Big rear wheel under the cab,
  small front wheel under the bonnet, cab with a window, roof overhanging it, exhaust
  between bonnet and cab, grille at the nose, fender and chassis between. The wheels are
  20 and 14 units across.
- **B: a working tractor facing right with a raised front loader.** The same anatomy plus a
  loader arm (drawn at −25°) over the bonnet and a bucket at its end: a different idea,
  not a recolour.
- Files: the two `.json` candidates (id `"tractor"`, level `"hard"`) and their
  `candidate-*-sheet.png`, all in `docs/briefs/m14/bugs7/tractor-redo/`; the kit's
  `docs/design/puzzles/tractor-{a,b}.png` are temporary (Delete list below).
- I recommend **A**: on the sheet it is the cleaner silhouette; B's loader reads, but its
  bucket sits high and adds a second focal point.

Decisions:
- Two candidates, A first and B second, both within the turn budget.
- A's picture spans x 7–57, left of centre; 62.5% is what the rule asks, centring is taste.
- B's bucket is `#00897B` (teal): every palette token left was within 0.08 of a piece in B.
- A keeps one repeated pair (roof and fender, both 20 × 4), inside Hard's two-pair limit.
- The files were written from `_template.json` by hand (dart and `tools/level.sh new` are
  refused here); `check` and `render` ran as the kit prints them.

## Self-check (review rules A1–5)
1. Every host setup: n/a proposal only — nothing ships; the files exist only for the check
   and render runs, and the sheet draws the one board (`puzzle_render_test`).
2. When kept state starts and ends: n/a proposal only — no timer, slot or state is added;
   the sheet's start is seed 1 with an unstarted clock.
3. How new state combines with others: n/a proposal only — no pause, wait, input or round
   change.
4. Stay in the job's folder: yes — every write is inside `allow:` (two candidate files, two
   sheets, two design renders, this report); `index.json` and `tractor.json` were never
   edited.
5. Stop rather than overstep: `tools/level.sh` and `dart` are refused by the sandbox, so I
   ran the kit's printed `flutter test` commands, wrote no test and no Dart; the two
   library files stay for the Delete list because I cannot delete files.

## Kit used
`tools/level.sh` itself was refused (`tools/level.sh --self-test`, `new`, `check` and
`render` each came back "requires approval"), and so was `dart`. As the brief allows, I ran
the exact commands the script prints:

| what | command | result |
| --- | --- | --- |
| check A | `cd packages/puzzle_game && flutter test --dart-define=puzzleId=tractor-a test/puzzle_check_test.dart test/puzzle_schema_test.dart` | `00:00 +4: All tests passed!` |
| render A | `cd packages/puzzle_game && flutter test --dart-define=puzzleId=tractor-a test/puzzle_render_test.dart` | `wrote ../../docs/design/puzzles/tractor-a.png (55126 bytes)` … `All tests passed!` |
| check B | `cd packages/puzzle_game && flutter test --dart-define=puzzleId=tractor-b test/puzzle_check_test.dart test/puzzle_schema_test.dart` | `00:00 +4: All tests passed!` |
| render B | `cd packages/puzzle_game && flutter test --dart-define=puzzleId=tractor-b test/puzzle_render_test.dart` | `wrote ../../docs/design/puzzles/tractor-b.png (62633 bytes)` … `All tests passed!` |

`new` has no flutter form, so the two files were made from `_template.json` exactly as
`new` would: same header order, id, name, level `"hard"`, and an `index.json` line was not
needed because `check <id>` and `render <id>` read the file directly. I therefore never
touched `index.json`.

## Computed values
From the checked files (board 80 × 72):

| | pieces | big | turned | pairs | smallest piece (size = 2 × farthest corner) | picture box |
| --- | --- | --- | --- | --- | --- | --- |
| A | 10 | bonnet, cab, rear wheel | 8, all non-circles | roof = fender (20 × 4) | front window, 10 × 10 = 14.1 units | x 7–57, y 14–57 |
| B | 11 | cab, bonnet, rear wheel | 9, all non-circles | none | window, 9 × 9 = 12.7 units | x 12–66, y 18.5–58 |

Rule results seen in this job: `checkPuzzle` empty for both (no piece, colour, span, tray
(seeds 0–199), split-scale or 8.5 mm floor issue); the sheets rendered with
`All tests passed!`. The mm figure prints only on a failure, so I have no mm number to
report for either.

`tools/check.sh format puzzle` after the last edit:
- `PASS format` (2 s).
- `FAIL puzzle` (435 passed, 3 failed, 91 s): every failure is the two candidate files
  sitting in `puzzles/` without index lines. `test/puzzle_check_test.dart` without an id
  prints exactly two issues — `puzzles/tractor-a.json is not listed in index.json…` and the
  same for `tractor-b` — and `library_test`'s "the whole library has no issues" and
  `puzzle_new_test`'s "the new puzzle passes the rule book unchanged" fail on those same
  two lines. With the files deleted (the Delete list) nothing else is out of place.

## Not done
- The candidate files and their two design renders are still in the library and
  `docs/design/puzzles/`; the runner deletes them from the Delete list, which leaves
  `packages/` and `docs/design/` byte-identical to the start (index unchanged).
- No change to `packages/puzzle_game/puzzles/tractor.json`, `index.json`, `docs/levels.md`
  or any test (out of the brief, which stops at the proposal).

## Questions and suggestions
1. The full `tools/check.sh puzzle` run is red only until the Delete list runs; I could not
   verify the green state myself. Please run it after the deletions.
2. Should the winner keep the shipped id `tractor` and replace `tractor.json`, or land as a
   new id so both pictures can be compared in the app? The proposals use `tractor` as asked.
3. A's cab has one window; B's sits on the cab's rear side. If "a window on the rear" means
   a back window drawn in addition to the side one, say so and the winner gets a second,
   differently shaped window.
4. A's picture sits left of centre on the board (x 7–57). Centring it is a two-number change
   if the owner wants the tractor in the middle of the board.

## Commit message
Propose two Hard tractor puzzles for the tractor redo

Replace nothing yet: two candidate tractor pictures are checked and rendered for the
owner to pick. Candidate A is a classic farm tractor facing left, with a small front
wheel, a big rear wheel, a cab with a window, a bonnet and an exhaust; candidate B is a
working tractor facing right with a raised front loader. Both are Hard data files (A 10
pieces, B 11, 3 big and every non-circle turned) that pass the rule book, and the sheets
show the start and the finished picture in Sunny and Night.

## Status row
Tractor redo: two Hard candidates (A recommended) checked and rendered as proposals — done; the owner's pick, the library swap and the two temporary files are open.

## Delete
- packages/puzzle_game/puzzles/tractor-a.json
- packages/puzzle_game/puzzles/tractor-b.json
- docs/design/puzzles/tractor-a.png
- docs/design/puzzles/tractor-b.png
