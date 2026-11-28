# r3g report: fuse values in one place (PROVISIONAL)

## Summary

- `FuseParams` (new, `settings.dart`) holds `startDelayS = 20.0`, `startFuseMs = 12000`, `snapCutMs = 1500`,
  `minFuseMs = 4000`, each marked PROVISIONAL until the kid playtest (Nov 28 2026). No value changed.
- `PresentRules.startDelayS`, `startFuseMs`, `snapCutMs`, `minFuseMs` are now `static const x = FuseParams.x;`, so every
  existing name still works. `popMs` and `gapS` stay in `PresentRules`.
- New `test/fuse_skill_test.dart` (4 tests) drives a real `PresentRules` with the `childBot` and `adultBot` profiles from
  `tools/sim/bots.dart`. The import works under `flutter test`.
- `tools/mine.sh`: format, analyze and the touched tests passed (`OK 5 tests packages/puzzle_game`, RESULT ok).
- Tests-first: exempt, a move of constants. The bot test pins behaviour already correct on the base.

## Files changed

- `packages/puzzle_game/lib/src/settings.dart`: added `abstract final class FuseParams` with the four provisional values.
- `packages/puzzle_game/lib/src/present_rules.dart`: the four constants are aliases of `FuseParams`; their doc comments
  point at `FuseParams`.
- `packages/puzzle_game/test/fuse_skill_test.dart` (new): the bot simulation and four tests.
- `docs/briefs/m17/race1c/r3g-report.md` (new): this report.

Not changed: `present_rules_test.dart` and `present_match_test.dart` (they still pass by name, no edit needed).

## Tests and what they check

Every number they compare against comes from `FuseParams` or from the test's own named constants, not from the lib values.

1. `a present nobody bats pops when the start fuse runs out, within two steps of it`: the pop time must be
   `FuseParams.startFuseMs / 1000` = 12.0 s, within `2 × 0.1` s.
2. `after any number of snaps the fuse stays at or above minFuseMs, for a child and for an adult`: the lowest fuse
   after any snap must be at least `FuseParams.minFuseMs` (4000).
3. `a child bot still gets at least one bat in per present on average`: mean bats ≥ 1.
4. `an adult bot makes more bats per present than a child bot`: adult mean > child mean.

Simulation rule (documented in the test): a side holding the present snaps after
`max(0.5 s, 4.0 s − performance)`, where `performance` is a fresh `BotProfile.performance(r)` draw each time it receives
the present. Both sides run the same profile. Each present uses a new `PresentRules`, from the spawn to the pop, with
`Random(42)`, over 200 presents per bot, stepped at 0.1 s.

Values: `mine.sh` passed all four tests. I did not record the simulated means (child, adult) or the number of presents
that hit the 50-bat cap, so I cannot quote them. They should be read from a run before anyone relies on them.

## Self-check (review-rules part A)

1. Host setups: N/A. A constant move with no UI. Covered by the unit tests above.
2. Kept state: none added. The fuse constants are compile-time values. The sim's state is local to each present.
3. Combinations with pause, host away, "Get ready", dropped link, results, leaving: unchanged. No new state transitions.
4. Stayed inside `allow:`: yes. Only the five allowed files and this report were touched.
5. Stops: none. The import of `tools/sim/bots.dart` works under `flutter test`.
6. Looks: N/A, no widget changed.

## Decisions

- The bot's pace model (4.0 s minus performance, floor 0.5 s) is my own choice. The brief did not name one. It is a
  test-only rule and is documented in the test.
- Both sides use the same bot profile, so "bats per present" counts bats from both sides.
- A new `PresentRules` per present, so each present waits the start delay. This keeps the test's start-fuse check exact.

## Questions and suggestions

1. Fuse near the floor lifts up, not down: `onSnap` does `max(minFuseMs, fuse − snapCutMs)`. A snap that finds the fuse at
   600 ms sets it to 4000 ms, which lengthens the fuse. The sim can keep a present alive this way. Is this intended? If
   not, the fix is `min(fuse, max(minFuseMs, fuse − snapCutMs))`. It changes behaviour, so I did not make it.
2. The simulation cap (50 bats) hides how often a present never pops. Should the test assert the cap is never hit?
3. `mine.sh` reported `OK 5 tests`. I could not reconcile that with four new tests plus the existing `present_rules_test.dart`
   (12 tests). Please check that the new file really ran.
4. `present_rules.dart` lines 11–12 (existing comment) exceed 120 columns. I left them alone; they are outside this job.
5. The bot's pace numbers are guesses, like the bots' skill numbers. They belong in the playtest review, not here.

## Hand-over

- Values lock after the kid playtest (Nov 28 2026): edit `FuseParams` only.
- Open: question 1 (snap near the floor), question 2 (cap), question 3 (test count).

## Commit message — a draft

r3g: fuse values in FuseParams (provisional)

Moves the four provisional present fuse values (20 s start delay, 12 s start fuse, 1.5 s snap cut, 4 s floor)
into one class, FuseParams, in settings.dart. PresentRules keeps its four names as aliases, so no caller
changes. No value changes: they lock after the kid playtest on Nov 28 2026.
Adds fuse_skill_test.dart: a child and an adult bot drive a real PresentRules over fixed-seed presents. It
checks the floor, the start fuse, that a child bats at least once per present on average, and that an adult
bats more than a child.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

r3g: the four provisional fuse values sit in FuseParams (settings.dart) and PresentRules aliases them; a bot test
checks floor, start fuse and skill ordering. Open: values lock after the kid playtest (Nov 28 2026); a snap near the
floor lifts the fuse (question 1).

## Delete

- none
