# race1c r3h3 report: a snap only shortens the fuse

## Summary

- A snap no longer lifts a short fuse. `PresentRules.onSnap` now uses the min form, so a fuse already under the 4000 ms floor stays where it is.
- Tests first: I added the "fuse under the floor, a snap leaves it" test before the fix. On the old code it failed: expected 3000 ms, actual 4000 ms (the lift).
- After the fix the same test passes. `tools/mine.sh` passes: 30 tests in puzzle_game.
- `fuse_skill_test.dart`: the old "fuse stays at or above minFuseMs" check relied on the lift, so I replaced it. The new check counts snaps that raised the fuse, or took it below both the floor and the fuse it found. It expects 0 for both bots. A new check expects 0 capped presents for both bots.
- `FuseParams` doc in `settings.dart` now says popMs and gapS stay in `present_rules.dart`, also PROVISIONAL.
- No value changed: 20 s, 12 s, 1.5 s, 4 s stay PROVISIONAL. No golden or host file touched.

Tests counted: 30 in puzzle_game (was 29 before my new present_rules test; the fuse_skill file keeps 4 tests, now 5 with the capped check).

Decisions:
- The new test went in the existing `present_rules_test.dart`, because the brief names that file and the allow list includes it. COMMON says new tests go in a new file. See question 1.
- The "no snap raises the fuse" check computes its counts from the states before and after each snap. The `_Present` typedef changed from `lowestFuseMs` to `badSnaps`.
- I did not change the bat cap value (50); only its doc comment, which claimed the old lift.

## Computed values

- Start fuse 12000 ms. Nine seconds of run-down with no snap gives 12000 - 9000 = 3000 ms. The new test expects 3000 after the left side's snap, with holder right.
- Old code: max(4000, 3000 - 1500) = 4000. That is the lift the test caught.
- New code: min(3000, max(4000, 1500)) = min(3000, 4000) = 3000.
- Simulation: 200 presents per bot, seed 42. Both bots: badSnaps 0, capped 0 (the test asserts these; I did not print the means or bat counts).

## Checks run

- `tools/mine.sh` run 4 times: first run failed on the new test (expected, pre-fix). After the onSnap fix: OK 25 tests. After the fuse_skill change: OK 30 tests. After the settings doc: OK 30 tests, 7 files formatted, 1 package analyzed. No analyzer findings.
- `dart analyze` on the changed files: covered by `mine.sh` (analyze of packages/puzzle_game, no findings).

## Hand-over

Files changed:
- packages/puzzle_game/lib/src/present_rules.dart: onSnap uses `min(_fuseMs, max(minFuseMs, _fuseMs - snapCutMs))`; doc says a snap never lengthens the fuse.
- packages/puzzle_game/lib/src/settings.dart: FuseParams doc names popMs and gapS as outside it, still PROVISIONAL.
- packages/puzzle_game/test/present_rules_test.dart: new test "a snap on a fuse already under the 4000 ms floor leaves the fuse as it was".
- packages/puzzle_game/test/fuse_skill_test.dart: `_Present` field `lowestFuseMs` replaced by `badSnaps`; `_breaksSnapRule` helper; two checks (no bad snap, no capped present) replace the old floor check; `_maxBatsPerPresent` doc corrected.

## Questions

1. COMMON says new tests go in a new file, but the brief names `present_rules_test.dart`. I followed the brief. Should the test move to a new file?
2. With the min form, the fuse can still run below 4000 ms between snaps (the run-down is not stopped by the floor). The floor now only limits what a snap leaves. Is that the intended design?
3. The bat cap can never be reached: the fuse always runs down, and presents pop before 50 bats. Keep the cap as a safety stop, or remove it?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

race1c r3h3: a snap only shortens the fuse

A snap on a fuse already under minFuseMs lifted it back to the floor, so
a snap could lengthen a present. onSnap now takes the min form: a fuse
under the floor stays as it is. The new test fails on the old code (3000
expected, 4000 got). The fuse skill test checks that no snap raises the
fuse and that no present reaches the bat cap. FuseParams doc names popMs
and gapS as outside it. No values change; all stay PROVISIONAL.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

r3h3 done: a snap never lengthens the fuse (min form, test fails on base); FuseParams doc names popMs/gapS; sim checks no bad snap and no capped present. Open: whether the bat cap stays (never reached); whether the fuse may run under the floor between snaps (Q2); new test file vs brief (Q1).

## Delete

- none
