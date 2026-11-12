# M14 p1 puzzle twins: review (read-only)

## Summary
Verdict: `small fixes` — 0 must, 3 should, 5 could.
- **should** `piece_twins.dart:124`: the mirror branch of the look-alike test uses the 3 % twin tolerance, so a mirrored pair 4–15 % apart of size is neither a twin nor a look-alike, though the brief counts mirror images as look-alikes.
- **should** test gap: nothing pins the 3 % twin tolerance or brief item 4 — raise `twinToleranceShare` to 0.15 and every new test still passes (the car would silently become all-twins).
- **should** `puzzle_painter.dart:209`: the new `_targetOf` (a locked piece's slot found by twin outlines) is not drawn by any test, so a twin sitting in its twin's slot is only checked in the rules.
- Otherwise the job is inside its folder, adds no snapshot field, no level change, no new player text, no leftover in `lib/`, and every file and function is within the size limits (puzzle_painter 305 lines, slot_paint 87, piece_twins 129).

## Findings
- **should** packages/puzzle_game/lib/src/piece_twins.dart:124 the mirror test runs `_turnOnto(mirrored, b)` with `twinToleranceShare` (3 % of the size, set at line 78), so two mirrored outlines 4–15 % apart in size are reported as neither twin nor look-alike, while the brief calls mirror images look-alikes and the scan test's own reading gates mirrors at `lookAlikeSizeShare` (15 %) → test the mirror at `lookAlikeSizeShare * max(a.size, b.size)` (scale one outline onto the other's size first).
- **should** packages/puzzle_game/test/puzzle_twins_test.dart:198 only the mirror pair checks that a non-twin does not fit, so nothing pins the 3 % corner tolerance or brief item 4 for a same-shape pair a few % apart; with `twinToleranceShare` raised to 0.15 all eight tests and the library scan still pass, and the car's headlight would silently fit its wheels' slots → add a same-shape pair 5 % apart that stays `wrong` and whose two slots are both hinted.
- **should** packages/puzzle_game/lib/src/puzzle_painter.dart:209 `_targetOf` now finds a locked piece's slot from the twin outlines instead of `kind`, and no test draws a board with a twin in its twin's slot (tests 1–3 assert `lockedTarget`, tests 4–7 draw every piece in the tray), so the mapping this decision relies on is unchecked → add a render or painter test that locks a twin in the other's slot and checks its own slot's outline is not drawn.
- **could** packages/puzzle_game/test/puzzle_twins_test.dart:245 the mirror test changes only the right wing's colour, so it passes whether the mirror colours look-alike targets only or every target; it has no non-look-alike control as the board test has with the dot → give a third piece a second colour between the two frames and assert its slot is unchanged.
- **could** packages/puzzle_game/test/twins_library_test.dart:67 the scan asserts that every pair inside a twin group is a direct twin, but `PuzzleTwins.groups` (piece_twins.dart:35-52) is built from links, and decision 3 says a chain A–B–C is allowed; a legal chain makes this test fail → assert what decision 3 promises ("linked by turns") or restate the decision as "groups are cliques".
- **could** packages/puzzle_game/test/twins_library_test.dart:34 the report's "test-local second reading" uses the rule's own `lookAlikeSizeShare` and `twinToleranceShare` (line 41) instead of its own numbers, so a wrong threshold in the rule cannot be caught by the scan → hard-code 0.15 and 0.03 in the test, or say in the report that the reading shares the constants.
- **could** packages/puzzle_game/test/twins_library_test.dart:76 `expect(twins.rotation(a, b), isNull)` and the `containsAll` on line 77 can never fail: `lookAlikePairs` only takes pairs whose rotation is null (piece_twins.dart:38) and `lookAlikes` is built from those pairs (piece_twins.dart:24) → delete them, or replace them with a fact about the library that could fail.
- **could** packages/puzzle_game/lib/src/mirror_painter.dart:134 the mirror draws a look-alike's target at `_targetLine` (0.5) alpha and `_targetFill` (0.18), fainter than the board's dashed edge in full colour, and the mirror test only proves pixels changed, not that the two wings can be told apart there → check on a device that the mirror's hint reads in Night (the report's own "try on a device" item) before calling decision 5 done.

## Decisions to confirm
- Decision 1 (no shipped Robo): the test-local "Robo" picks each piece with `twins.rotation` and then sets the drop angle from that same call (puzzle_twins_test.dart:264-266, `into` at 73-76), so it proves the rule against itself; confirm the brief only wanted a rule-level completion test, not a CPU player's choice.
- Decision 3 (groups are links) against the scan's pairwise assertion (finding at twins_library_test.dart:67): one of the two has to give.
- Decision 4 (no snapshot field, the painter guesses the slot): safe today because only `_filled` and the drop write slots, but it duplicates the rules in the view; pair it with the render test of finding 3.
- The report's question 2: the butterfly's file has purple/orange upper wings and green/blue lower ones, not the screenshot's brown and purple; the owner's answer decides whether artwork changes, and it is outside this job either way.

## Could not check
- The tests and `tools/check.sh` were not run (the suite rewrites `docs/design/puzzles/*.png`, `docs/design/m13-placed-look.png` and `site/shots/*.png` per the report's note, and this job may change only its report), so the pixel counts (660/613/632/735/2993), the totals (puzzle 371, host 380, phone 463) and the scan's printed list are unchecked at runtime; the scan table was checked by hand against the twelve level files and matches, including the car's 14/12 circles (14.3 %), the train's 15.26/13.89 radii (9.0 %) and the rocket's and butterfly's mirror pairs.
- A1's "a phone or host one build older" was not played: the diff adds no snapshot field and no protocol change, which I did verify.

## Commit message
Review: M14 p1 puzzle twins, findings only

Read the twin fit rule, the slot and mirror hint, the painter's slot
look-up and the two new tests against the guidelines, review-rules
part A and the brief.
No must; three should: the mirror look-alike size gap, no test for the
3 % twin tolerance or brief item 4, and no test of the painter's twin
slot mapping. Five could, mostly test hygiene in twins_library_test.
The scan table matches the level files by hand; the checks were not run
because the suite rewrites committed pictures.

## Status row
M14 p1 puzzle twins: review done — no must, 3 should, 5 could; open: the mirror look-alike size gap, a test for the 3 % twin tolerance, a render test for a twin in its twin's slot, and the owner's answer on the butterfly's colours.

## Delete
- none
