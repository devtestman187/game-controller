# race1c r3h report: golden slot fixes

## Summary

Three fixes to the golden slot, as the brief names them.

1. **Input object.** `GoldenSlot.update` took 8 parameters. The four board readings (`openLeft`, `openRight`, `placedLeft`, `placedRight`) now sit in a new value object `GoldenInputs` (in `golden_slot.dart`). `update` is now `update(dt, {required enabled, required inputs})`: 3 parameters. `random:` is gone; the held `_random` is used. `_weight` and `_pick` take the same object, so nothing carries 5 parameters.
2. **Read-only state.** `slot` and `claimedBy` are getters over private `_slot` and `_claimedBy`. Nothing outside the class assigned them.
3. **Gap rename.** `gapS` is now `glowGapS`, with a doc line saying it is the golden gap and not `PresentRules.gapS` (15.0). Its value is still 10.0. The over-120 doc line at old :38 is rewrapped.
4. **No claim on a wrong re-snap.** `_awardSnap` in `puzzle_points.dart` now runs the golden claim only when `!again`. A try again pays its normal `wrongSnap` and leaves the slot glowing.
5. **Tests.** Tests came first: the new re-snap test failed on the base code (see Checks). One-board test added. The Chaos-off test is renamed to say what it checks.

Values computed for the expectations (`pointsScale` 1, from `PuzzlePoints`):
- first-try snap on the glowing slot: base 2 x 2 (golden double) = **4**
- wrong re-snap on the glowing slot: `wrongSnap` 1, no golden double = **1** (base code gave 1 + 1 = **2**)
- snap on one board, or on two boards with Chaos off: base **2**
- `gapS` is 10.0 here, `PresentRules.gapS` is 15.0 (unchanged, not touched)

## Files changed

- `packages/puzzle_game/lib/src/golden_slot.dart`: new `GoldenInputs` value object; `update` takes `inputs:` and no `random:`; `slot`/`claimedBy` read-only getters over private fields; `gapS` renamed `glowGapS` with its golden-gap doc; `_weight`/`_pick` take `GoldenInputs`; `stepBoards` builds the object. 139 to 158 lines.
- `packages/puzzle_game/lib/src/puzzle_points.dart`: `_awardSnap` claims only when `!again`, with a comment saying why.
- `packages/puzzle_game/test/golden_slot_test.dart`: call sites moved to `GoldenInputs`, `random:` removed; new tests for the one-board snap, the wrong re-snap (with a `misplace` helper that drops the piece on the board centre and asserts the state is `wrong`), and the honest rename of the Chaos-off test.

`match.dart` is not changed. The brief named its "update call", but `match.dart` never calls `update`; it calls `stepBoards`, whose signature did not change. I made no edit there.

## Checks

- Tests first, on the base code: `tools/mine.sh` ran the new file. The re-snap test failed with `Expected <1> Actual <2>`. The other new tests passed on base, which is expected: they pin behaviour that was already correct. (The first try of this test also failed on setup, `PieceState.loose` instead of `wrong`, because the drop point was off the board. That was fixed by dropping at the board centre, before the fix.)
- After the fix: `tools/mine.sh`: `OK 11 tests packages/puzzle_game`, `dart analyze packages/puzzle_game` clean (no infos), `3 file(s) formatted`. Final result: `RESULT: ok`.

## Review-rules self-check (part A)

1. Host setups: no UI or wire change. The golden slot runs in the match for every host (race test uses the same match path). Covered by the existing 11-test file.
2. Kept state: `_slot`, `_claimed`, `_delayS`, `_waitedS`. Starts empty, ends on claim or clear. Tests: "a slot glows only after the first delay", "a glowing slot that both sides have locked clears, with no claim", "the first claim wins".
3. Combination with pause, host away, player away, "Get ready", dropped link, results, leaving: no new state crosses these. The wrong re-snap rule only changes which snaps claim. Covered by "no slot glows when the present gate is off, on Wild, or on one board".
4. Files: only the three allowed `lib`/`test` files, plus this report. `docs/briefs/m17/race1c/run.log` was already modified before the job started and is not mine.
5. Nothing stopped.
6. Looks: no UI. N/A.

## Hand-over

Done. Open for the owner: see the questions below.

## Questions and suggestions

1. **The brief says a wrong re-snap "pays 2".** That number is the bug. Base code gives 1 (try again) + 1 (golden) = 2. The fixed rule gives 1. The test asserts 1, as the owner's suggestion ("only a correct snap claims") implies. Please confirm 1 is the intended value.
2. **Try-again pieces and the golden double.** A piece that the cat knocked out counts as a try again (`again` includes `wronged`/`placedOnce`), so it also no longer claims. This follows the owner's wording, but confirm the cat case too.
3. **Suggestion:** `golden_slot.dart` is 158 lines and the test file 176, both well under the limits. No split needed.

## Commit message — a draft

Fix the golden slot: a wrong re-snap does not claim it

GoldenSlot.update took 8 parameters (cap 5), so the board readings now
travel in a GoldenInputs value object and update takes 3. slot and
claimedBy are read-only getters over private fields. gapS is renamed
glowGapS: it is the golden gap (10 s), not the present's (15 s).

_awardSnap claims the golden slot only for a correct snap. A try again
pays its own point and leaves the slot glowing; it paid double before.

Tests: the re-snap test failed on the old code (2 points, not 1); one-board
snap test added; Chaos-off test renamed to say what it checks.

## Status row

r3h done: golden slot takes GoldenInputs (3-param update), slot/claimedBy read-only, gapS renamed glowGapS, wrong re-snap no longer claims. Open: owner to confirm a re-snap pays 1 (brief said 2) and that cat knock-outs count as try agains.

## Delete

- none
