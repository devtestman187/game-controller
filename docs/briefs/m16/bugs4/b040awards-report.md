# B-040 awards in the phone's standings: report

## Summary

On a night's last round, the phone's standings now include the +3 per award, as the host's final scores do. The change adds `NightState.withAwards()`, which decides the awards from the night's numbers. `PartyNight` uses it at the night's end (last round and early end), and `viewResultsFor` uses it when the round it projects is the night's last. No protocol, message, field or host screen changed, and who wins an award is decided by the same `decideAwards` as before.

Files changed:
- `packages/party_host/lib/src/night/night_state.dart`: new `NightState withAwards()` (documented), returning `awarded(decideAwards(...))` from the night's awards, counters, rounds won, last-round points and the players it has met.
- `packages/party_host/lib/src/night/party_night.dart`: `recordRound` and `endNow` call `withAwards()`; private `_decide` removed; its now-unused import of `night_award_results.dart` removed.
- `packages/party_host/lib/src/night/round_results.dart`: `recorded` is the night after the round; `after` is `recorded.withAwards()` only when `recorded.isOver`. A comment says an early-ended night is not known here.
- `packages/party_host/test/round_results_test.dart`: two new tests and a `resultOf` helper (see below).

## Tests

Tests added in `round_results_test.dart` (the file the brief names; it is an existing file, not a new one):

1. `the last round's standings add the +3 an award gives, as the host's final totals do`. Roster: Mia (p1, number 1), Ben (p2, number 2). Night of 3 with `threeAwards` (Best Helper, Comeback, Sharpshooter). Rounds 1 and 2 recorded through `recordRound`: round 1 `{p1: 6, p2: 4}`, round 2 `{p1: 3, p2: 3}`, so totals are Mia 9, Ben 7. Last round: points `{p1: 0, p2: 0}`, stats `{p2: {carries: 1}}`.
   - Best Helper counts `carries` (most, at least 1): Ben has 1, Mia none, so Ben wins +3.
   - Comeback needs last-round points of at least 1: both are 0, so nobody wins it.
   - Sharpshooter needs `wrongDrops` and `snaps`: neither is present, so nobody wins it.
   - Expected: Ben 7 + 3 = **10**, Mia 9. Order Ben, Mia.
   - Asserts: `viewResultsFor(...)['p1'].standings` names `['Ben', 'Mia']`, points `[10, 9]`; equal to `night.record(last).withAwards().rows(players)` totals `[10, 9]`; after `recordRound(last)`, host rows ids `['p2', 'p1']`, totals `[10, 9]`.
2. `a round one of three of a night carries no award points`. Same roster; night of 3 with `threeAwards`; round 1 `{p1: 6, p2: 4}` with stats `{p2: {carries: 1}}`. Asserts `round == 1`, `of == 3`, standings points `[6, 4]` (Mia 6, Ben 4, no +3 for Ben's carry, because the night is not over).

Checks run:
- `tools/mine.sh` (before lib change): FAILED. It reported `withAwards` undefined and a const-eval error on my first draft of `RoundLine(count: 0)` (a `RoundLine` with `count` needs `countOf`; I removed `count`). So the first run showed a compile failure, not an assertion failure. The test 1 assertion-level failure against the old lib was therefore not observed separately.
- `tools/mine.sh` (after lib change): `OK 16 tests packages/party_host`, `RESULT: ok: 4 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- `flutter test` on the existing night files (run in `packages/party_host`): `party_night_test`, `night_award_results_test`, `end_night_arena_test`, `end_night_puzzle_test`, `night_reveal_test`, `night_reveal_tie_test`, `night_robo_test`, `night_round_test`, `night_screens_test`, `arena_night_test`: `All tests passed!` (+86).

Self-check (review-rules part A):
1. Host setups: the change is in `viewResultsFor` and `PartyNight`, shared by all hosts; covered by `night_round_test`, `end_night_*_test` and `arena_night_test` passing. No new phone path.
2. Kept state: `withAwards()` is a pure copy; `outcomes` is only replaced on the last round or early end, as before. Empty night: `viewResultsFor` with `night == null` is unchanged (`recorded` null, so `after` null).
3. Combinations: pause menu, host away, player away, "Get ready", dropped link, results and leaving do not touch awards. Early end: see question 1.
4. Files: only the allowed four lib/test files plus this report.
5. Nothing overstepped.
6. Looks: no UI change.

## Decisions

- Test 1 uses a last round with zero points so that Comeback does not join in; the single award it checks is Best Helper's.
- The brief's "tests first" was followed by writing the test first; the first run failed on the missing method, so the assertion-level red was not seen. Test 2 is a guard for the not-over case; it passes on the old code too, by design (it fails if `withAwards` is applied on every round).
- `round_results.dart` uses the local name `recorded` for the night after the round.

## Questions

1. An early-ended night (B-021): the phone's `viewResultsFor` runs before the host decides, so the phone's standings for that last recorded round still lack the +3. The host's final scores include it. This matches the brief ("cannot be known here"). If the phone must match the host there too, it needs the awards sent with the result, which is a protocol change and out of this job.

## Suggestions

- The standings for an early end could be corrected when the host's final scores arrive, if any message carries them; that is outside this job.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
bugs4 B-040: the phone's standings on a night's last round carry the awards

The phone projected the night's last round without deciding its awards, so
its standings left out the +3 per award the host's final scores include and
could name another winner. NightState.withAwards() decides them as PartyNight
does at the night's end, and viewResultsFor uses it on the last round only.
Early ends are not known to the phone and keep the old standings (open).
Tests: round_results_test (last round adds the award; round 1 of 3 does not).
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

B-040 (awards in phone standings): done: last-round standings add the awards, via NightState.withAwards(); tests in round_results_test. Open: a night ended early still shows the phone's standings without the awards (needs the awards sent with the result, a protocol change).

## Delete

- none
