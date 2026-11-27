# g3m report: the real round placing and champion chain behind the City interfaces

## Summary

Added the adapter that puts the real placing and champion chain behind the City
interfaces in `stubs.dart`. Two new classes in one new library, plus a new test
file. Nothing else was touched: no rules, no wiring into a game or the night flow,
`stubs.dart` and `night/` unchanged.

Classes (`packages/party_host/lib/src/city/night_adapter.dart`):
- `RoundResultPlacing(RoundResult)` implements `RoundPlacing`. Reads each listed
  id's `place` stat from `RoundResult.stats`. A listed id with no `place` stat is
  placed after the placed ones, in the order listed. A duplicate id throws
  `ArgumentError`, as the stub does.
- `NightChampionDecider([ChampionChain? chain])` implements `ChampionDecider`.
  Maps each `CityChampionEntry` to a `ChampionEntry(id: playerId, points: 0,
  plazaDistance, bolts)` and runs `chain.champions`. Default chain is
  `ChampionChain.cityRush`.

Test file (`packages/party_host/test/city/night_adapter_test.dart`), 13 tests, all passing:
- RoundResultPlacing: `gives each player the place stat the round recorded`;
  `places a player with no place stat after the placed ones, in the order listed`;
  `places every listed player 1, 2, 3 in order when the round has no places at all`;
  `ignores a place stat for a player who is not listed`;
  `refuses a player id listed twice, since one player cannot hold two places`.
- NightChampionDecider: `picks the entry closest to the Plaza`;
  `breaks an equal distance to the Plaza by the most bolts`;
  `shares the win when distance and bolts are both level`;
  `gives an empty set when there are no entries`.
- Shared contract, run on the stub and the adapter: `stub` / `adapter`
  `RoundPlacing gives exactly one placing per listed player`;
  `stub` / `adapter` `ChampionDecider never returns an id that is not among the entries`.
- The existing `stubs_test.dart` (5 tests) still passes.

Computed values behind the expectations:
- Placed round: ann=2, ben=1. Listed `['cy','ann','dee','ben']` gives cy=3, dee=4
  (placed max is 2, so unplaced players take 3, 4 in listed order).
- No stats: `['ann','ben','cy']` gives 1, 2, 3.
- Distance/bolts: ann(2,1), ben(2,3), cy(5,9) gives ben (ties on distance, ben has more bolts; cy is further).
- Level: ann(2,3), ben(2,3), cy(4,0) gives {ann, ben}.

Self-check (docs/review-rules.md part A):
1. Host setups: not applicable, pure Dart, no host screen. Covered by the unit tests only.
2. Kept state: none. Both classes are stateless apart from the constructor values; empty input is tested for the decider, and for the placing with no stats.
3. Combination with pause menu, host away, results, etc.: not applicable, nothing is wired in. Adapter is not used by any game or screen yet.
4. Folder and allow: only the two allowed `.dart` files and this report were changed.
5. Stop: nothing needed stopping for.
6. Looks: not applicable, no UI.

Analysis: `dart analyze` on both changed files: No issues found.

## Decisions

- Unplaced players are numbered after the highest place among the listed players (not after the count of placed players), so a gap in the recorded places is kept and the unplaced get the next numbers. Example: places 1 and 3 recorded, one unplaced player gets 4.
- Players with equal recorded places keep them; the adapter does not re-rank them.
- `NightChampionDecider` constructor is not `const`: `ChampionChain.cityRush` is a `static final`, not a constant, so the default cannot be a const initializer. Tests therefore build it without `const`.
- Points are fixed at 0 for every entry, because the City Rush steps never read points.
- Did not use `docs/briefs/m17/board3m/probe-g3m.patch`; its stubs return empty sets and were not used as the implementation.

## Hand-over

- Checks run: `dart format` on both files (the runner check failed on format; the driver ran dart format, see run.log HAND-FIX); `flutter test test/city/night_adapter_test.dart test/city/stubs_test.dart` (13 + 5 tests = 18 in total, all passed); `dart analyze` on both files (no issues).
- Not run: `tools/mine.sh` and `tools/check.sh`. The brief says "never tools/mine.sh", while the job prompt asks for `tools/mine.sh`; I followed the brief. The runner's format/analyze/host step will cover the rest.
- The new test file was written before the implementation file existed; the test would fail to compile without it, so it fails on the code as it was.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 board3m g3m: adapter for the real round placing and champion chain

Adds night_adapter.dart with RoundResultPlacing (reads each player's place
stat from a RoundResult, unplaced players after the placed ones) and
NightChampionDecider (maps City entries to the night's ChampionChain, default
cityRush). It is the only City file that imports night/ and game_kit.
Tests in night_adapter_test.dart cover both classes and run the shared
contract on the stub and the adapter. Nothing is wired into a game or the
night flow yet.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3m g3m: done: RoundResultPlacing and NightChampionDecider behind the City interfaces, 18 tests pass; open: nothing is wired to a game or the night flow yet.

## Delete

- none
