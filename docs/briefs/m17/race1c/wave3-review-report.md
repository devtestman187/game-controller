# Review of wave 3 (r3g): fuse values in FuseParams

## Summary

verdict: small fixes
counts: 0 must, 5 should, 2 could
top 3:
1. The bot test cannot fail for the behaviour reason on the base: it references `FuseParams`, which the base lacks, so it only fails to compile there (run.log:36 says it "fails on the old code"). The tests-first exemption rests on this.
2. `onSnap` lifts a nearly spent fuse up to `minFuseMs` (a snap at 600 ms sets 4000 ms). The job did not change this line, and the sim relies on it. Claude must decide the rule.
3. The bot test records `capped` and never asserts it, so the 50-bat cap that ends a present is hidden from the check.

## Findings

- **should** packages/puzzle_game/test/fuse_skill_test.dart:4 `FuseParams` is missing on the base, so the new test fails to compile there, not on the behaviour it names → say in the report that the base run is a compile failure, or drop the tests-first exemption and record it as not shown.
- **should** packages/puzzle_game/lib/src/present_rules.dart:76 `_fuseMs = max(minFuseMs, _fuseMs - snapCutMs)` raises a fuse of 600 ms to 4000 ms, so a snap lengthens a present near its pop (unchanged by r3g) → Claude decides; if the rule is "a snap only shortens", use `min(_fuseMs, max(minFuseMs.toDouble(), _fuseMs - snapCutMs))`.
- **should** packages/puzzle_game/test/fuse_skill_test.dart:32 `capped` is set at line 54 and read nowhere, so no check sees a present that hit `_maxBatsPerPresent` → assert the capped count is 0 for both bots, or remove the field.
- **should** packages/puzzle_game/lib/src/settings.dart:161 the `FuseParams` doc says the fuse numbers are "in one place", but `popMs` and `gapS` (present_rules.dart:27-32) are also PROVISIONAL and stay outside it → name the two outside constants in the doc, and fix the hand-over (r3g-report.md:72).
- **should** docs/briefs/m17/race1c/r3g-report.md:11 says `OK 5 tests packages/puzzle_game`, but the touched files hold 4 new tests plus 13 in present_rules_test.dart (grep count of `test(` calls) → the report's test count does not match the files; re-run the touched tests and record the real count.
- **could** docs/briefs/m17/race1c/r3g-report.md:67 says lines 11–12 of present_rules.dart exceed 120 columns; only line 11 does (line 12 is within the limit) → correct the line range.
- **could** packages/puzzle_game/lib/puzzle_game.dart:31 `export 'src/settings.dart'` makes `FuseParams` part of the package's public surface, which the brief did not ask for → keep it (the test needs it) or export it from a narrower library; decide which.

## Decisions to confirm

- The snap rule in `onSnap` (present_rules.dart:76) is not changed by this job, but the bot test relies on it. Confirm the lift is intended.
- The bot pace (`max(0.5 s, 4.0 s − performance)`), the 50-bat cap and the 200-present seed-42 runs are the job's own choices (fuse_skill_test.dart:13-26). They are listed in the report, but they set what the test measures.
- `FuseParams` is public through `puzzle_game.dart:31` (see the could above).
- Tests-first is recorded as exempt (r3g-report.md:12), yet run.log:36 says the test fails on the old code. The run shows the compile failure, not a behaviour failure.
- Each present uses a new `PresentRules` (r3g-report.md:57), so the sim never exercises the gap after a pop (`gapS`). That is accepted by the report; confirm it is wanted.

## Could not check

- Test results: I did not run `flutter test` or `mine.sh` (review is read-only), so the "OK 5 tests" line, the simulated means and the 50-bat cap counts are unverified.
- The run.log:36 claim that the test "fails on the old code" was read, not reproduced; the compile reason is inferred from the missing `FuseParams` symbol.
- Whether `import '../../../tools/sim/bots.dart'` works under `flutter test`: the report says it does; not run.
- `docs/briefs/m17/race1c/run-findings.md` has no entry about r3g (its one line is about r3f).
- Analyzer output for the changed files: not run.
