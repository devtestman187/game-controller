# Review of wave1 (r3a): PresentState in the match snapshot

## Summary

- Verdict: **small fixes**
- Counts: must 0 · should 4 · could 3
- Top findings:
  1. `present.dart:34`, `:36`, `:37` and `snapshot.dart:361`: bare `0.5` breaks the no-magic-numbers rule.
  2. `present_snapshot_test.dart:98`: the 40-byte budget test passes when no present is encoded at all.
  3. `present.dart:6` and `:23`: the public constructor and `fromJson` have no dartdoc.
- Brief: all six numbered items are done. Nothing built is missing; one extra (`toString`) is listed under Decisions.
- Self-check lines in r3a-report.md: all checked against the code and true, except the hand-over line (finding 4).

## Findings

- **should** packages/puzzle_game/lib/src/present.dart:34 `t < 0.5` appears three times (lines 34, 36, 37), a bare magic number → name it as a `static const` with a doc comment (why: the switch happens at halfway) and use it on all three lines.
- **should** packages/puzzle_game/lib/src/snapshot.dart:361 the new `present` lerp uses the bare `0.5` a fourth time (the `cat` line at 360 already had one before this job) → use the same named constant from present.dart.
- **should** packages/puzzle_game/test/present_snapshot_test.dart:98 the budget check `lessThanOrEqualTo(presentMaxBytes)` also passes if the present is dropped (added = 0), so it does not prove the 40-byte budget → add `greaterThan(0)` with a reason, so the test fails when no `pr` is written.
- **should** packages/puzzle_game/lib/src/present.dart:6 the public `const PresentState(...)` constructor has no dartdoc → add a one-line doc (what the fields mean at construction).
- **should** packages/puzzle_game/lib/src/present.dart:23 the public `static PresentState fromJson` has no dartdoc → add one line saying it reads the `pr` entry written by `toJson`, with `popped` as 1 or 0.
- **should** docs/briefs/m17/race1b/r3a-report.md:75 the Hand-over says "Nothing staged or committed", but commit af673590 contains all five changed files and `present.dart` is no longer untracked → replace the line with "Committed in af673590".
- **could** packages/puzzle_game/lib/src/present.dart:52 `toString` is not in the brief's list (`==` and `hashCode` only) → drop it, or confirm it as wanted (see Decisions).
- **could** packages/puzzle_game/lib/src/present.dart:23 `PuzzleSide.values[j[0] as int]` and the `as int` casts are unvalidated, so a bad index throws a RangeError on a malformed frame → same pattern as `CatView.fromJson`; accept it at this boundary, or validate and default to a state the caller handles.
- **could** packages/puzzle_game/test/snapshot_eight_players_test.dart:1 (imported as `show nightFrame, playerCounts` by present_snapshot_test.dart:6) couples the two test files → accept, since the brief allowed it; a shared helper file would remove the coupling if more tests need it.

## Decisions to confirm

- `toString` added to `PresentState` (present.dart:52): not in the brief; small and harmless, but it is extra surface.
- `nightFrame` and `playerCounts` imported from `snapshot_eight_players_test.dart` instead of copied: allowed by the brief; the report says so. Confirm the import is the choice you want.
- `cat_snapshot_test.dart` left unchanged although it is in `allow:`: the brief names no edit to it, so this is correct; the report's open question 2 asks whether it should carry a present.
- Holder, fuse total and pop switch at halfway (present.dart:34-37): this is what the brief specifies; listed only so the owner sees the rule.

## Could not check

- `docs/briefs/m17/race1b/run-findings.md` does not exist in the race1b folder, so there are no run entries about "passes on the old code".
- I did not run any tests (read-only job). The 500-test count and the `tools/mine.sh` output in the report are not verified here.
- The 23-byte size is by hand: `,"pr":[1,12345,15000,0]` counts 23 characters. Not measured with load8.
- Rules were checked against the worker extract's copy in the brief; the full `docs/coding-guidelines.md` and `docs/review-rules.md` were not read in full.
- A new test that fails on the old code cannot be shown by running it: the new file does not compile without `PresentState`. The brief exempts it from tests-first.

## Commit message — a draft

```
Review r3a: PresentState snapshot findings

Read-only review of the wave1 job r3a against the coding guidelines,
the review rules and its brief. No code changed. Findings: a bare
0.5 in the present lerp, a size test that passes with no present,
missing dartdoc on the public constructor and fromJson, and a stale
hand-over line in the r3a report. Verdict: small fixes.
```

## Status row

M17 race1b wave1 review of r3a: small fixes (0 must, 4 should, 3 could); no code changed. Open: the named constant for the halfway switch, the size-test lower bound, dartdoc on PresentState, the r3a hand-over line.

## Delete

- none
