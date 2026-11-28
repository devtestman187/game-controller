## Summary

Done: the hot-potato present's rules, as a pure Dart class with its tests. Nothing is wired into the match, the view or the settings yet (the brief's stop).

Files changed:
- `packages/puzzle_game/lib/src/present_rules.dart` (new): `PresentRules`, with the six PROVISIONAL constants (`startDelayS` 20, `startFuseMs` 12000, `snapCutMs` 1500, `minFuseMs` 4000, `popMs` 1500, `gapS` 15), `enabled(PuzzleSettings)`, `state`, `onSnap(PuzzleSide)`, `update(dt, enabled:, oneBoard:)`, `end()`. It uses no PuzzleEventKind; a pop is the state's `popped` flag. Doc lines say the present never costs a piece.
- `packages/puzzle_game/lib/src/present_rules.dart` also holds a private `_msPerS` (1000), so the ms/s conversion has a name.
- `packages/puzzle_game/test/present_rules_test.dart` (new): 15 tests, each named for the rule it checks. Written before the class, as the brief says.
- `packages/puzzle_game/lib/puzzle_game.dart`: one export line for `src/present_rules.dart`, after `present.dart`.

Checks run: `tools/mine.sh` twice. The first run failed analyze on three `avoid_redundant_argument_values` infos in the test file; I removed the redundant arguments (the defaults are `Chaos.off` and `CatPreset.lively`). The second run: 3 files formatted, analyze clean, `OK 514 tests packages/puzzle_game`.

## Computed test values

All steps use `update(1.0, ...)`, so every value is exact:
- Start: 19 runs, null. The 20th run (clock 20 >= 20) brings the present, holder left, fuse 12000 of 12000.
- Three more runs: fuse 9000.
- Holder (left) snaps: holder right, fuse 9000 - 1500 = 7500.
- Snaps by right, left, right: fuse 6000, 4500, then 4500 - 1500 = 3000, which the floor lifts to 4000 (holder left).
- Other side's snap (right, while left holds): state unchanged.
- Four runs at fuse 4000: fuse 0, popped, holder left.
- One more run: pop still out (popLeft 500). A second run: gone (popLeft -500). Then 14 runs: null; the 15th: present out, holder right, fuse 12000.

## Self-check (review-rules part A)

1. Host setups: not wired yet, so no host is affected. Covered by nothing in this job; the wiring job must test each setup.
2. Kept state: starts after `startDelayS` or `gapS` after the last pop; ends at the pop, on disable, or on `end()`. Tests: "no present comes before the start delay", "a popped present stays for 1500 ms, and the next one comes 15 s after it is gone".
3. Combinations with pause, host away, player away, Get ready, dropped link, results, leaving: the class only takes `enabled` and `oneBoard`; the caller must pass `enabled: false` for those states. Test: "disabling the rules removes the present at once", "end() clears the present, and no later update brings one back".
4. Only the four allowed files changed.
5. No stop needed.
6. Looks: none, no widget.

## Decisions I made (please check)

1. Alternation: the first present is held by left. Each later present starts with the side that did not start the previous one (left, right, left...). The brief's "then alternating" could also mean the holder changes on each snap only; I took the first reading.
2. Disabling: the present is removed and the clock restarts. After re-enable the wait is `startDelayS` if no present has come yet, else `gapS`.
3. `end()` is permanent for the instance: `update` and `onSnap` do nothing afterwards.
4. The snap cut uses `max(minFuseMs, fuse - snapCutMs)`, so the fuse can never rise on a snap.
5. The fuse counts in a double internally and is rounded for `state`, so no drift shows in the frame.
6. `enabled` is `chaos != off && catPreset != wild`, in one static method as the brief asked.

## Questions

1. Is decision 1 (alternation per present) right, or should the holder simply alternate on each snap?
2. Should a disable reset the clock (as built) or keep it running?

## Suggestions

- The wiring job should own the "Get ready", pause and away gates; this class only knows the two flags.
- Consider a test with `dt` that is not a whole second, since the fuse rounding is untested there.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

present: add PresentRules, the hot-potato present's rules

Adds PresentRules (pure Dart): a present comes after 20 s or 15 s after the last pop, held by left first and then
alternating. Each snap by the holder bats it to the other side and cuts its fuse by 1500 ms, never below 4000 ms.
At 0 it pops on the holder's side for 1500 ms. enabled() is off for chaos off and for the Wild cat.
Not wired into the match or the view yet; the fuse values are PROVISIONAL until the kid playtest (r3g).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

r3b done: PresentRules (bat on snap, fuse cut to a 4000 ms floor, pop on the slow side, gap, enabled gate) with 15 tests; open: not wired into match or view, fuse values PROVISIONAL until the kid playtest (r3g).

## Delete

- none
