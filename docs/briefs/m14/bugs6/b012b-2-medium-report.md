## Summary

Phase 2 of B-012b: Medium is harder by its pieces, and all six Medium pictures are redrawn in place.

- **New limits**, named constants in `puzzle_rule_levels.dart`: 8 to 10 pieces, at
  least 4 turned (circles never count), 1 or 2 big, at most one repeated pair — the
  six `medium*` constants; `puzzle.schema.json`'s description and `docs/levels.md`'s
  table say the same. The old 6 to 8 were the owner's "too easy".
- **The six pictures**, same id and subject: boat 8 pieces / 4 turned / 1 big,
  car 9/4/1, robot 9/5/1, train 9/5/1, castle 9/4/1, butterfly 8/6/1. Every piece is
  at least 8.66 mm on the floor's phone (8.5 mm), the split board stays 0.99 to 1.18
  of its one-board size, and each picture spans 53-78% by 49-72% of the board.
- **Old Medium best times no longer compare**: each was set on a smaller picture.
- **Tests**: new `test/medium_limits_test.dart` (a 7-piece and a 3-turned Medium
  refused, a 9-piece with 4 turned accepted; both fail on the old limits), the
  Medium cases of `puzzle_rules_test.dart` follow the new numbers, and
  `library_test.dart` is green over all twelve puzzles with 6 Medium (unchanged).
- **Checks**: `tools/check.sh format analyze puzzle` — format, analyze and puzzle
  PASS (433 tests).
- **Scratch**: `test/tmp_brief_png.dart` and `test/tmp_medium_measure.dart` are
  empty files; the sandbox refused `rm`, so both are in Delete.

Pictures for the owner (640 × 360, solved and start), in `docs/briefs/m14/bugs6/b012b-2-medium/`:
- docs/briefs/m14/bugs6/b012b-2-medium/boat-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/boat-start.png
- docs/briefs/m14/bugs6/b012b-2-medium/car-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/car-start.png
- docs/briefs/m14/bugs6/b012b-2-medium/robot-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/robot-start.png
- docs/briefs/m14/bugs6/b012b-2-medium/train-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/train-start.png
- docs/briefs/m14/bugs6/b012b-2-medium/castle-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/castle-start.png
- docs/briefs/m14/bugs6/b012b-2-medium/butterfly-solved.png · docs/briefs/m14/bugs6/b012b-2-medium/butterfly-start.png

## Self-check (review-rules part A)

1. **Every host setup.** The change is level data and the rule book, with no view,
   input or protocol change, so a TV/PC host, a phone on "Play on this phone" or
   "Show on this device", a joined phone and an older peer draw the same pieces
   from the frame: `puzzle` `test/library_test.dart` and `test/puzzle_check_test.dart`
   PASS; the host, phone and TV suites are **not run** (this diff does not reach them).
2. **When kept state starts and ends.** Nothing is held, timed or cached: a piece's
   start angle and tray place stay a pure function of the puzzle and seed.
   `puzzle`: `test/puzzle_rules_test.dart` (tray seeds 0-199) PASS.
3. **How a new state combines with the others.** No new pause, wait, block or phase;
   the redrawn pictures only change values the existing layouts read. `puzzle`:
   `test/split_layout_test.dart` and `test/tablet_board_test.dart` PASS.
4. **Stay in the job's folder.** Only `allow:` paths were written: this report, the
   brief's picture folder, `puzzle_rule_levels.dart`, `puzzles/`, `test/`,
   `docs/levels.md` and `docs/design/puzzles`. The puzzle suite rewrites
   `docs/design/m13-puzzles*.png` (outside `allow:`); the job's copies were put back
   byte for byte (question 1).
5. **Stop rather than overstep.** `rm` is refused in this sandbox, so the two
   scratch tests are left empty and listed under Delete; no file outside `allow:`
   was edited.

## Decisions

- **`_medium` reuses `_counts` with a `_mediumCounts` record**, as Hard does, so a
  count message is worded once for both levels.
- **A turned circle does not count toward the 4**: the rule reads
  `rotated && symmetry != 0`, matching `_turned` and Hard, since a circle looks the
  same at any angle.
- **The boat's two waves now differ** (20 × 6 blue, 20 × 4 green) instead of sharing
  one shape: `tray_packing_test` found two identical waves packed in one row at 50%
  overlap ("wave 1 is too hidden"), and two different waves also keep the repeated
  pair count at 0. The boom went from slate to orange, because slate stands 0.0487
  from its empty slot where the rule asks for 0.1.
- **The boat's phone mirror is now the largest that fits beside the clock area**
  (94.45 px) rather than the board fraction (98.7 px), so `mirror_place_test`
  asserts `lessThanOrEqualTo(fraction)`; the rect and width pins still fix its size
  exactly.
- **`rules_test`'s "boat has two waves of one kind" became "8 pieces, 4 turned"**:
  the waves are no longer one kind, since a repeated pair must share a shape.
- **`docs/levels.md` gained one table row and per-level sentences**, worded like the
  Easy and Hard text around them, rather than a second list.

## Computed test values

- The rule book's new messages, verbatim: `a Medium puzzle has 8 to 10 pieces, this
  one has 7.` and `a Medium puzzle starts at least 4 pieces turned, this one starts
  3.`; a 9-piece puzzle with 4 turned has no level issue.
- The library: 6 Easy, 6 Medium, 0 Hard; all six Medium pass `checkPuzzle` with no
  issues at seeds 1-21 of the 8.5 mm floor and seeds 0-199 of the tray.

| Picture | Pieces | Turned | Big | Smallest piece | Split / one board | Span |
| --- | --- | --- | --- | --- | --- | --- |
| boat | 8 | 4 | 1 | 10.79 mm | 1.097 | 75% × 56% |
| car | 9 | 4 | 1 | 10.15 mm | 1.175 | 64% × 51% |
| robot | 9 | 5 | 1 | 8.66 mm | 0.988 | 53% × 72% |
| train | 9 | 5 | 1 | 9.00 mm | 1.169 | 65% × 49% |
| castle | 9 | 4 | 1 | 8.75 mm | 1.000 | 78% × 72% |
| butterfly | 8 | 6 | 1 | 9.27 mm | 1.159 | 68% × 56% |

Re-pinned layout values, old → new:

- `camera_test`: boat 4.6304 → **5.3536** at 667 × 375, 4.5934 → **5.3108** at
  734 × 372. House, rocket and tree unchanged.
- `mirror_place_test`: boat mirror 92.94 × 76.62 → **94.45 × 66.67** px; its scale
  4.8527 → **5.6107** px per unit.
- `tablet_board_test`: solo iPad boat 9.699315 → **11.209614** and the small iPad
  7.661124 → **8.930159**; worlds 241.280/120.941/1124.720/906.128 and
  238.103/96.940/941.897/722.460; portrait world 0/117.374/1024/1027.488 and clock
  173.8/1035.488/712.424/1150.176; landscape split boat 394.966…971.034; 852 × 393
  solo 204.911…647.089 and split 315.456…536.544. House unchanged.
- `puzzle_pieces_test`: boat main sail (42, 28, 58, 50), jib (27, 35, 38, 49), flag
  (41.2, 28, 48.2, 34).
- `frame_size_test`: the boat's frame holds 8 pieces now, 678 bytes.

## Checks run

- `tools/check.sh format analyze puzzle`: PASS format (3 s, 0 changed), PASS analyze
  (9 s), PASS puzzle (**433 tests**, 53 s). Run three times while the scratch tests
  were tidied; the last run is the one quoted.
- `flutter test` in `packages/puzzle_game` before that: 439 tests passed (the 433
  plus the two scratch tests' six).
- `tools/level.sh check` and `render`: **not run** — the sandbox refused to start
  the script; its two check tests ran inside the puzzle suite and
  `test/puzzle_render_test.dart` wrote `docs/design/puzzles/`.
- `host`, `phone` and `tv` suites: **not run**. Their only pinned puzzle geometry is
  in `controller_app/test/puzzle_size_test.dart`, which was not run either.

## Questions

1. The puzzle suite rewrites `docs/design/m13-puzzles.png` and
   `m13-puzzles-night.png`, which sit outside this job's `allow:` (and
   `docs/levels.md` says to commit them with a puzzle). This job restored them; may
   a follow-up commit the redrawn sheets, which now show the new Medium pictures?
2. `rm` is refused in this sandbox, so two scratch tests are left as empty files:
   delete them at commit (Delete, below).
3. Old Medium best times were set on 6- or 7-piece pictures; should a later job
   clear the stored bests for Medium, or is a mixed comparison acceptable until the
   Hard ones arrive?

## Commit message

```
Puzzle: Medium needs 8-10 pieces, 4 turned, and the six pictures redone

puzzle_rule_levels.dart's Medium limits become named constants: 8 to 10
pieces, at least 4 turned (circles don't count), 1 or 2 big, at most one
repeated pair; the schema's description and docs/levels.md take them.

The six Medium files keep their ids and subjects, rebuilt from the shape
kit at 8 or 9 pieces. Camera, mirror, tablet, piece and frame tests are
re-pinned to the new boat; medium_limits_test.dart is new and
rules_test.dart follows the changed boat.
```

## Status row

`- B-012b phase 2 done: Medium's limits are 8-10 pieces, at least 4 turned, 1 or 2 big and at most one repeated pair, and the six Medium pictures (8-9 pieces, every piece at least 8.66 mm) are redrawn; old Medium best times no longer compare. Open: a Hard puzzle in the library and its limits (phase 3).`

## Delete

- packages/puzzle_game/test/tmp_brief_png.dart
- packages/puzzle_game/test/tmp_medium_measure.dart
- packages/puzzle_game/test/tmp_m13-puzzles.png
- packages/puzzle_game/test/tmp_m13-puzzles-night.png
