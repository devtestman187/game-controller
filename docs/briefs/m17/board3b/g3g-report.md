# g3g report: night_sim_test.dart findings fixed (checks only)

## Summary

Changed: `tools/sim/night_sim_test.dart` only (checks, two constants, two helpers).

- Replaced the vacuous gate check with three gate checks (5 games, `rulesWith(standard, tileCost: 1)`, 300 seeds).
  The gate tile is read from `gateTileIndex` (4 in the standard rules).
- Added the mid-ranking checks (5 games, 200 seeds): `midLast`, `midLeaders`, `firstPlazaGame` (range and equality
  with a value computed from `tilesAfterGame`), and `leaderReachedPlaza`.
- Replaced "roadworks cost 0 still runs" with a bolts comparison: roadworks cost 0 against the standard cost, same
  seeds (0..299), roadworksChance 1, saveChance 0.

Test values seen in the run of `bash tools/tests/sim-test.sh` (all PASS):

- roadworks cost 0 leaves more bolts: 2328 against 1986 at the standard cost over 300 nights
- gate: after games 1 and 2 no player has more than 4 tiles over 300 nights
- gate: some night has a player at 4 tiles after game 2 (300 of 300 nights)
- gate: some night has a player above 4 tiles after game 3 (300 of 300 nights)
- mid ranking: midLast is a player of the night over 200 nights
- mid ranking: midLeaders is not empty and holds only players of the night over 200 nights
- firstPlazaGame is null or between 1 and the games over 200 nights
- firstPlazaGame is the first game whose stop has a complete road over 200 nights
- leaderReachedPlaza is true exactly when a champion has 6 tiles over 200 nights

Old roadworks checks still PASS in the same run: blocksReceived sums to blocksPlaced (300 nights), some night has a
player with blocksReceived >= 2 (93 of 300), some night has an own pick (173 of 300), some night has a rival pick
(294 of 300), champions are the place-1 set (100 nights).

Self-check (review-rules part A):

1. Host setups: not affected; the file tests the simulator only.
2. Kept state: not affected (no state in the sim test; each check builds its own nights from seeds).
3. Combinations: the new checks use the standard rules with one change each (`tileCost`, `roadworksCost`); the kids
   check is unchanged.
4. Only `tools/sim/night_sim_test.dart` and this report were changed.
5. Nothing overstepped; `night_sim.dart` and `bots.dart` are unchanged.
6. Looks: not applicable (no UI).

## Decisions

- Gate checks use 5 games and the default four-player bots (`fourPlayers`), roadworks on, so the cap binds for at least
  one player on each night. Reason: the brief names a 5-game night.
- The mid-ranking checks use `longNightGames` (5) and `midSeedCount` (200) as named constants, not literals.
- `firstPlazaFromTiles` recomputes the first plaza game from `tilesAfterGame`, so `firstPlazaGame` is checked against
  an independent computation, not against itself.
- The roadworks cost check reuses the existing `rwNights` (standard cost, 3 games) as the priced side: the brief says
  "with the standard cost" and this keeps the same seeds and profiles.
- Check names keep the "name states the rule" style of the file.

## Blocked

- `tools/mine.sh` reports `FAILED tests .` for `tools/sim/night_sim_test.dart`, in two runs, and I could not see the
  failing check. Its output is capped to the first 8 lines under the test name, and those 8 lines are all PASS. Its
  summary also says `1 file(s) formatted` on each run.
- What I ruled out: `bash tools/tests/sim-test.sh` (which runs the same file with `dart run`) shows every check PASS,
  and its whole run takes about 8 s. The file as it stands passes under `dart run`. So the failure comes from the
  `dart test` run that `mine.sh` makes, or from a check that only fails there. I did not run `dart test` on the file
  directly, because the rules allow only `tools/mine.sh` for checks.
- What would settle it: a `mine.sh` log that shows the lines after the 8th (or running `dart test tools/sim/night_sim_test.dart`
  from the repository root by hand, outside this job).
- I did not run `dart analyze` on the file by itself, so analyzer infos are unchecked. `mine.sh` prints analyzer errors
  only, and it printed none.

## Questions

1. The brief's `stop:` line says "never tools/mine.sh", but the job's instructions say to check with `tools/mine.sh`.
   I followed the job's instructions and ran `tools/mine.sh`.
2. `tools/mine.sh` fails on this file with a hidden cause (see Blocked). Should the 8-line cap be raised for `dart test`
   output, or should the file's main be split into `test()` calls so each check is reported?
3. The "1 file(s) formatted" note appears on each `mine.sh` run. Is the formatter output stable for this file, or
   is something else rewriting it?

## Suggestions

- Wrap the checks in `test()` calls (package:test) so `mine.sh` shows the failing check by name.
- The `playerIds` list duplicates the id scheme `'p$index'` from `night_sim.dart`; a shared helper would keep them in
  step.

## Hand-over

Left for the reviewer: the `mine.sh` failure above. The file passes `tools/tests/sim-test.sh`, every check PASS. The
analyzer and format status from `mine.sh` are not confirmed beyond "no analyzer errors printed".

## Commit message — a draft

Fix the three test findings of the wave-2 review in night_sim_test

Replace the gate check that could not fail with three gate checks at tileCost 1 (cap binds, cap holds after games
1 and 2, a player above the gate after game 3). Add checks for midLast, midLeaders, firstPlazaGame and
leaderReachedPlaza over 200 nights. Replace the roadworks cost 0 check with a bolts comparison against the standard
cost over the same 300 seeds, since a cost of 0 must leave more bolts.

## Status row

m17 board3b g3g: the three review test findings are fixed in night_sim_test.dart (gate, mid-ranking, roadworks cost 0)
and pass `sim-test.sh`; open: `tools/mine.sh` reports a FAILED test run with the cause hidden by its 8-line cap.

## Delete

- none
