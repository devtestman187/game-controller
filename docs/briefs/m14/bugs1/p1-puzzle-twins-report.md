# M14 p1: Shape Race puzzles with near-identical pieces — report

## Summary
- A twin piece now fits any of its twins' slots, at any turn that lays its outline on the slot's, and the picture completes when every slot holds a piece that fits it (boat waves, car and train wheels, robot eyes, castle towers, and any rotated copy a later puzzle adds).
- A piece a turn cannot exchange but the eye cannot tell apart — the rocket's fins, the car's wheels and headlight, the train's engine and carriage, the butterfly's four wings — now has its slot's dashed outline, and the mirror's faint outline, drawn in its own colour, in Sunny and Night. All other slots are unchanged.
- Files: `piece_twins.dart` (new), `puzzle.dart`, `puzzle_drop.dart`, `puzzle_tick.dart`, `puzzle_painter.dart`, `slot_paint.dart` (new), `mirror_painter.dart`, plus the two new test files (listed below). No level file and no asset changed.
- Decisions: the brief's Robo test is a test-local player, because Shape Race has no CPU player; circles count as look-alikes within 15 %; the painter finds a locked piece's slot from the outlines instead of a new snapshot field. Details under Decisions.
- Not done: nothing in the brief is skipped. `docs/levels.md` does not mention twins, but it is outside this job's files; the drawn design pictures (`docs/design/puzzles/*.png`, `m13-placed-look.png`) also show the old slots and are outside this job's files.
- Note: the suite's picture tests rewrite `docs/design/puzzles/*.png`, `docs/design/m13-placed-look.png` and `site/shots/*.png`, and `flutter pub get` rewrites `tv_test_app/windows/flutter/generated_*`; all of these are outside `allow:`, so I put them back as committed. They need regenerating by a job that may touch them.
- Try on a device: the Butterfly — each wing's slot is now its own colour, and a wing dropped on the other wing's slot stays red; the Boat — either wave snaps into either wave's slot; a joined phone's mirror of the Butterfly — the other side's wing outlines are in their own colours.

## Files changed
- `packages/puzzle_game/lib/src/piece_twins.dart` (new): `PuzzleTwins`, the twins and look-alikes of one puzzle, worked out from the outlines; `twinToleranceShare` (3 %) and `lookAlikeSizeShare` (15 %).
- `packages/puzzle_game/lib/src/puzzle.dart`: `Puzzle.twins`, built in the constructor when the puzzle loads; the new part file.
- `packages/puzzle_game/lib/src/puzzle_drop.dart`: the fit rule and the hint/telemetry target take a twin's slot at the fit angle (`_fitAngle`), and a snap uses that angle; nothing else about the drop changed.
- `packages/puzzle_game/lib/src/puzzle_tick.dart`: the ready and hint highlights read the slot of the fit rule's record.
- `packages/puzzle_game/lib/src/puzzle_painter.dart`: a locked piece finds its slot by the outlines it is a twin of (so a piece in its twin's slot draws that slot as filled); the slot's paint moved out.
- `packages/puzzle_game/lib/src/slot_paint.dart` (new): the slot, its fill and its dashed edge, with the look-alike's edge in the piece's own colour; moved here so `puzzle_painter.dart` stays at 305 lines.
- `packages/puzzle_game/lib/src/mirror_painter.dart`: the mirror's faint target outline is in the piece's colour for a look-alike.
- `packages/puzzle_game/lib/src/view.dart`: lists the new part file.
- `packages/puzzle_game/test/puzzle_twins_test.dart` (new): 8 tests, below.
- `packages/puzzle_game/test/twins_library_test.dart` (new): the library scan, below.

## Decisions
1. **No production Robo.** Robo is the Bumper Round's CPU marble (M14 b3) and does not exist in Shape Race; the brief's "Robo's piece choice" and "Robo completes a puzzle with twins" are met by a player named Robo inside the new test that chooses a piece for each slot and plays the puzzle to the end. Adding a shipped CPU player would be a new feature outside this bug's brief.
2. **Circles follow the same 15 % rule.** Two circle pieces whose diameters are within 15 % (the car's wheels at 14 and its headlight at 12, 14.3 %) cannot be told apart by shape, so they are look-alikes too; the brief's "same shape" includes a circle.
3. **Twin groups are links, fitting is pair by pair.** A group is the pieces joined by twin turns, for the scan's list; a slot is only ever accepted by a piece whose own outline coincides with it, so a chain of near-twins can never make a pair fit that does not coincide.
4. **No snapshot field.** The painter finds a locked piece's slot from the outlines it fits, nearest place wins, instead of adding a target index to `PieceView`. The frame format is unchanged, so a phone one build older still draws (review rule A1).
5. **The mirror takes the hint too.** The mirror draws every outline faintly rather than empty slots; the brief says "if they draw slots", so a look-alike's faint outline is drawn in its own colour there as well, which is what makes the wings tellable apart on the other side.
6. **Slot paint moved to its own file.** `puzzle_painter.dart` was 378 lines and the hint is a slot paint; moving `_slot`, `_outline` and their constants to `slot_paint.dart` keeps both files well under the 380-line limit and splits along a responsibility seam.
7. **Ready and hint keep their meaning.** A ready or hinted slot still draws in `good`/`focus`, not the piece's colour; those states already say "drop here" and are not the ambiguity the owner reported.

## Scan: every puzzle in the library
Printed by `twins_library_test.dart` (piece ids in the puzzle's order). "None" means the puzzle has no such pair.

| Puzzle | Twin groups | Look-alike pairs |
| --- | --- | --- |
| house | none | none |
| rocket | none | "left fin" + "right fin" (mirror) |
| tree | none | none |
| sun | none | none |
| fish | none | none |
| snowman | none | none |
| boat | "wave 1" + "wave 2" | none |
| car | "wheel front" + "wheel back" | "wheel front" + "headlight" (sizes 14 and 12); "wheel back" + "headlight" |
| robot | "eye left" + "eye right" | none |
| train | "wheel front" + "wheel back" | "engine" + "carriage" (26x16 and 24x14, 9 % apart) |
| castle | "tower left" + "tower right" | none |
| butterfly | none | "upper left" + "upper right" (mirror); "lower left" + "lower right" (mirror) |

The test fails if a pair of pieces that a test-local second reading (side lengths and corner angles, sizes within 15 %) calls alike is neither a twin nor a look-alike, so a puzzle added later cannot bring the bug back. Today's library passes.

## Tests
Each new test file failed on the old code first (no `Puzzle.twins`, no `PuzzleTwins`; the compiler refused both files).

`test/puzzle_twins_test.dart`, 8 tests:
1. "a twin fills its twin's slot, and the picture completes with the twins swapped": `rotation(left, right)` = 0; the left piece locks in the right one's slot (`lockedTarget` 1), then the right in the left's; phase finished, 3 placed.
2. "a twin turned in the level file fills its twin's slot at the turn that lays it on": the second outline is the first turned 90°, so `rotation(0, 1)` = 90° and `rotation(1, 0)` = 270°; the placed angle snaps to 90°; phase finished.
3. "a mirror pair is not interchangeable…": both rotations null; the pair is a look-alike pair and both pieces are hinted; a wing dropped on the other wing's slot stays `wrong`, 0 placed.
4. "a look-alike's slot is dashed in its own colour in Sunny, and another slot is not": at 1280 x 720 (8 px per unit), pixels within 2 px of a slot's outline that are within a colour gap of 32 of the piece's colour — left 660, right 613, dot 0.
5. The same in Night: left 632, right 735, dot 0.
6. "the mirror draws a look-alike's slot in that piece's own colour in Sunny": two mirror frames of the same puzzle with the right wing's colour changed; pixels that change inside its target 2993, inside the left wing 0, inside the dot 0.
7. The same in Night: 2993, 0, 0.
8. "Robo plays a twin puzzle to the end, choosing a piece for each slot that fits it": Robo takes the last free piece that fits each slot, so the two twins swap places; phase finished, 3 placed.

`test/twins_library_test.dart`, 1 test: the scan table above, the twin groups' pair-by-pair fits, and the second-reading check.

Checks: `tools/check.sh format analyze puzzle host phone` — all PASS; puzzle 371 tests (362 before, 9 new), host 380, phone 463.

## Self-check (docs/review-rules.md part A)
1. **Every host setup.** Rules and painter are the same on a TV or PC host, a phone on "Play on this phone" and a joined phone; the mirror is its own painter. Tested by the board and mirror render tests in both looks, plus the host and phone suites. A peer one build older is unaffected: the snapshot version and fields are unchanged.
2. **When kept state starts and ends.** `Puzzle.twins` is computed once, when the puzzle loads, and is immutable; it holds no timer, no round state and no player data, so nothing to end and nothing to leak. Tested by the library scan and every twin test.
3. **How a new state combines with the others.** Nothing new pauses, hides, waits or blocks input; the fit rule only widens which free slots a held piece may snap into, and the ready/hint colours still win over the hint colour. Tested by tests 1–3 and 8 here, and the existing ready/hint tests in the passing suite.
4. **Stay in the job's folder.** Only `packages/puzzle_game/lib/src`, `packages/puzzle_game/test` and this report were written; no asset, level or app file changed.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; the only brief item that does not fit the code is Robo, handled as decision 1 without adding a shipped feature.

## Questions
1. Should Shape Race get a shipped Robo-style CPU player of its own, now that the brief assumes one? (Not built here.)
2. The brief's screenshot says the butterfly's large wings are brown and purple; the file has purple and orange (upper) and green and blue (lower). Is the artwork to change, or was the screenshot's colour memory off?

## Suggestions
- Add a line to `docs/levels.md`'s puzzle rules saying that twins fit either slot and look-alikes show their colour, so a level author knows why the butterfly's wings are coloured.
- Consider an author-time warning in `tools/level.sh check` when a look-alike's colour is close to another slot colour on the same board, so two hints cannot look alike.
- Regenerate the design pictures (`docs/design/puzzles/*.png`, `m13-placed-look.png`) in a job allowed to touch them, so the butterfly's picture shows the coloured wing slots.

## Commit message
Shape Race: twins fit each other's slots, look-alikes get a colour hint

A piece now fits any slot it is a turn away from, so the boat's waves, the
car's and train's wheels, the robot's eyes and the castle's towers swap, and
a piece stored a quarter turn off fits its twin.
Pieces a turn cannot exchange but the eye cannot tell apart (the rocket's
fins, the car's wheels and headlight, the train's engine and carriage, the
butterfly's wings) get their slot's dashed outline, and the mirror's faint
outline, in their own colour in both looks.
Twins come from the outlines when a puzzle loads, so no level file changed;
the library scan test lists every pair and fails on a new puzzle whose
look-alike pairs the rule does not cover.

## Status row
M14 p1 puzzle twins: done — twins swap and complete in the rules, look-alikes carry a colour hint on the board and the mirror, library scan test in place; open: a shipped Shape Race CPU player (the brief's Robo), docs/levels.md wording.

## Delete
- none
