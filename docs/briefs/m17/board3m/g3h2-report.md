# board3m g3h2 report

## Summary

Fixes run-review findings 1 and 8 (REVIEW.md) and the decider part of finding 9. Test-only and doc-only; no behaviour change.

Files changed:
- `packages/party_host/test/city/rules_test.dart`: replaced the chain test at :65 with `forPlayers(6).forPlayers(4)` expecting 3 (old code gives 2); added `forPlayers(6).tileCost` expecting 2; deleted the chain at :69 (`forPlayers(6).forPlayers(2).forPlayers(6)`), which gives 2 on both old and new code, so it cannot guard the fix.
- `packages/party_host/test/city/night_adapter_test.dart`: added the gap test (see below).
- `packages/party_host/lib/src/city/night_adapter.dart`: doc only on the `NightChampionDecider` constructor: the chain must not read points, since every entry carries 0.

Test names changed:
- added `a 4-player night re-prices a copy that was priced for 6 players to 3 Bolts a tile` (replaces the :65 test)
- added `a copy priced for 6 players costs 2 Bolts a tile`
- removed `a 6-player night re-prices a copy that was priced for 2 players to 2 Bolts a tile`
- removed `re-pricing a copy for 6 players then 2 players then 6 players ends at 2 Bolts a tile`
- added `places an unplaced player after the highest recorded place, not after the count of placed players` (night_adapter_test.dart, in `RoundResultPlacing`)

Computed values (by reading `rules.dart:111-125`, the code at HEAD, and `git show` of the pre-fix version in 8f9e3e61):
- `forPlayers(6).forPlayers(4).tileCost`: new 3 (4 < largeNightFrom, so the small-night price 3); old 2 (the copy's own tileCost, 2 from the first call).
- `forPlayers(6).forPlayers(2).forPlayers(6).tileCost`: old 2, new 2 (so deleted).
- `forPlayers(6).tileCost`: 2 on both (a guard, not a fail-on-old test).
- gap test, recorded {ann: 3, ben: 1}, `placeRound(['cy', 'ann', 'ben'])`: new gives cy 4 (highest recorded 3, plus 1); count-based would give cy 3. Current code gives 4, so the test passes.

Checks:
- `tools/mine.sh`: `OK 66 tests packages/party_host`; `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. Format, analyze and the touched tests pass.

Self-check (review-rules part A):
1. Host setups: the change touches only the City rules and the night adapter, which both host kinds share; no host-specific code. Covered by the existing `rules_test.dart` and `night_adapter_test.dart` groups.
2. Kept state: none. The adapter and the rules are pure functions of their inputs.
3. Combination with pause, host away, player away, Get ready, dropped link, results, leaving: not applicable to pure rules and placing.
4. Edits stayed inside `allow:` (and this report).
5. Nothing stopped.
6. No look or UI changed.

Tests-first: exempt. The new checks pin behaviour already correct on the base, except the :65 replacement, which the brief says fails on the pre-fix code (verified by reading the history, not run; the pre-fix code is not checked out here).

## Hand-over

- Not run: the old-code failure of the new tests. I did not run them against the old code (that needs a checkout, which this job does not allow); the old values above come from reading the history.
- Brief conflict: the brief's `stop:` line says "never tools/mine.sh", while the job's instructions and `check:` say to run `tools/mine.sh`. I followed the job instructions and ran `tools/mine.sh` only. It covers format, analyze and the touched tests, so the separate `flutter test` / `dart format` / `dart analyze` steps in the brief were not run one by one.
- `docs/briefs/m17/board3m/run.log` shows as modified in `git status` with 17 added lines. It was already modified at the start (`M` in the status snapshot), and I did not edit it; I did not check whether `tools/mine.sh` wrote to it. Not reverted (git changes are not allowed here).
- `tools/mine.sh` reports "1 package(s) tested" with 66 tests in `packages/party_host`, the whole package, not only the city tests.

## Commit message — a draft

board3m g3h2: forPlayers chain tests, adapter gap test, decider doc

Fixes run-review findings 1 and 8 (and the decider part of 9). The forPlayers chain tests now include
6 then 4 (expects 3, the old code gave 2), and the 6 then 2 then 6 chain, which passed on the old
code, is removed. The adapter gets a gap test: unplaced players go after the highest recorded
place, not the count. NightChampionDecider's doc says the chain must not read points, since every
entry carries 0. Tests and docs only; no behaviour change.

## Status row

g3h2 done: forPlayers chain tests (6→4 expects 3, the 6→2→6 chain removed), adapter gap test, decider doc; mine.sh OK 66 tests. Open: old-code failure of the new chain test not run (needs a checkout); run.log shows modified in git status, not checked.

## Delete

- none
