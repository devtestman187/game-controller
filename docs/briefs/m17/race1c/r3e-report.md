# race1c r3e: mirrored golden slot rules (report)

## Summary

The golden slot's rules now exist as pure Dart, and a two-board match runs them on the present's gate. A glowing
target is picked after `firstDelayS`, weighted towards the side behind; the first claim on it pays the snap twice.
No painter, snapshot, wire, host UI or settings field was touched. `tools/mine.sh` passes: format, analyze
(no findings), and the package's tests (551 OK, this run).

Tests written: 8 in `test/golden_slot_test.dart` (new file). Their expectations, as written:
- a slot glows only after 10 s: `m.golden` null at 9.516 s (190 frames of 0.05 s after the 0.016 s start), not null at 10.516 s.
- first claim doubles the snap: left gains 4 points (snap 2 x 2), then `m.golden` is null.
- Chaos off, no golden: a snap gives 2 points (base, pointsScale 1).
- no slot in 60 s on Chaos off, on Wild, or on one board.
- nothing glows while disabled, even after 1000 s.
- a slot both sides lock clears, and cannot then be claimed.
- the first claim wins, only for the glowing target; a second claim on the same target gives false.
- side behind: 3000 picks with fixed seed 7; left placed 2, right placed 1; expected right's own share 10/15 = 2/3,
  asserted within 0.05; left's own slots get 0 picks. I did not print the observed count; the assertion passed.

Not verified: I did not run the new tests against the base code. The first `tools/mine.sh` run was made after both
the test file and the lib were written, so the "fails on base" proof is by reading only (the test file calls
`GoldenSlot`, which does not exist on base, so it would not compile there).

## Decisions

- **Signature kept, one exception.** `GoldenSlot.update` takes the seven named arguments the brief gives, which is over
  the five-parameter rule. Kept as specified. `stepBoards` is the match's entry point and takes four named arguments.
- **Random held by the slot.** `GoldenSlot(this._random)` gets the match's random, so `match.dart` needs no extra
  random field and stays within the 12-line cap (12 added, 1 changed). `update` still takes `random:` as the brief says.
- **`stepBoards` takes the match's games**, not left and right, to save match.dart lines. It finds the left and right
  games by `side`, falling back to the only game on one board.
- **Claimed targets never glow again.** The brief did not say. Without this, the other side could still have the target
  open after the claim, and a second claim (and a second double) could come. Excluded from picks.
- **Gap after a clear.** A glowing slot that both sides lock clears, and the next pick waits `gapS` from that moment,
  the same as after a claim.
- **Tie weight.** A target open only on one board, with the two sides level, weighs 1 (no bias); on the leader's
  board only it weighs 0.
- **Gate.** `enabled: _result == null && PresentRules.enabled(_settings) && format.split`. Once the round is over, the
  slot clears. Disabled also clears the glowing slot, so a settings change mid-round takes it away.
- **Test expectation for the snap.** The snap test assumes `flatWorld`'s piece `i` snaps to target `i` (it does: each
  piece is placed in its own outline, and the matcher takes the nearest free target).

## Self-check (review-rules part A)

1. Host setups: no host UI touched; the rule runs for any match on two boards (test: "a slot glows only after the first delay").
2. Kept state: `slot`, `claimedBy`, `_claimed`, the wait. Starts empty; clears on a claim, on a both-locked slot, or when disabled or the round ends (tests: the both-locked clear, the disabled test).
3. Combinations: the gate covers Chaos off, Wild, one board and a finished round (test: "no slot glows when the present gate is off..."). The pause, host away and dropped link are not in this job's code: a pause stops the round's update, so the wait stops too.
4. Folder: only the files in `allow:`.
5. Stop: none needed.
6. Looks: none touched (no painter).

## Hand-over

- Files changed:
  - `packages/puzzle_game/lib/src/golden_slot.dart` (new): `GoldenSlot`, the pick, gap, claim and clear rules, and
    `stepBoards`. Constants `firstDelayS = 10.0`, `gapS = 10.0` marked PROVISIONAL.
  - `packages/puzzle_game/lib/src/puzzle_points.dart`: `_awardSnap` awards the snap's base points a second time when
    `golden?.claim(side, target)` is true.
  - `packages/puzzle_game/lib/src/game.dart`: `GoldenSlot? golden` field (null default), and the import.
  - `packages/puzzle_game/lib/src/match.dart`: one `GoldenSlot` per match, given to the games on two boards only,
    stepped in `update`, and a `golden` getter (slot index or null). 12 lines added.
  - `packages/puzzle_game/lib/puzzle_game.dart`: exports `golden_slot.dart`.
  - `packages/puzzle_game/test/golden_slot_test.dart` (new): 8 tests, listed above.
- Checks run: `tools/mine.sh` three times (the first two with failures, fixed; the last: ok, 6 files formatted,
  1 package analyzed, 1 package tested, 551 tests OK).
- Not touched: `points_test.dart`, `match_test.dart` (both allowed, no change needed).

## Questions

1. The brief's `update` is seven parameters; the five-parameter rule says value object. Do you want a `GoldenInputs`
   value object now, or after the playtest?
2. Should a claimed target stay closed for good (as built), or may it glow again once both sides lock it?
3. Should a pause or a host-away freeze the slot's wait? Today `update` is only called while the round steps, so a
   pause already freezes it; confirm that is what you want.

## Suggestions

- Add the golden slot's state to the snapshot (`MatchSnapshot`) in a later job so both boards can draw the glow.
- `PuzzlePointsRules._awardSnap` now has two `_award` calls for a golden claim; a later job could fold the double into
  one call if the pop-up should show one number.

## Commit message — a draft

race1c r3e: golden slot rules (double snap, two boards)

Adds GoldenSlot, a pure-Dart rule set: a target glows after 10 s (PROVISIONAL) on a two-board
match on the present's gate, weighted to the side behind, and the first claim pays the snap
twice. A claimed target never glows again; a target both sides lock clears with no claim.
PuzzleGame gets an optional golden field (null on one board); PuzzleMatch owns one and steps it.
No drawing, snapshot, wire or settings change.

## Status row

r3e golden slot rules: done (pure Dart `GoldenSlot`, double snap on the first claim, two-board match only, 8 tests).
Open: the painter and snapshot glow, the settings field, and the playtest values (firstDelayS, gapS).

## Delete

- none
