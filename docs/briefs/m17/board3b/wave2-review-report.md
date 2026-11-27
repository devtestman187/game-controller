# Review of wave 2 (g3d2): the night simulator core

## Summary

Verdict: small fixes
Counts: must 1 · should 4 · could 3
1. The gate-tile test (night_sim_test.dart:212) cannot fail: after game 1 no player can hold more than 1 tile, so the cap of 4 never binds.
2. The gate-tile block is inert in any 3-game night, so the provisional assumption is untested end to end.
3. night_sim.dart is 379 lines (target about 300) and `simulateNight` is 49 lines (target about 40); split the types out.
Checks I ran: `bash tools/tests/sim-test.sh` (output matches the report line for line); `dart analyze tools/sim`: No issues found.

## Findings

- **must** tools/sim/night_sim_test.dart:212 The "before the gate game" check (lines 212-219) asserts tiles <= 4 after game 1, but with standard rules no player can hold more than 1 tile after game 1 (place 1 has 5 Bolts = tilesToBuy 1; the last place's Roadworks own pick adds 1; buildCap 3 and tileCost 3 cap the rest), so the check passes with the gate cap removed → add a 5-game night (gate game 3) with `rulesWith(..., tileCost: 1)` that checks `tilesAfterGame[1]` <= `gateTileIndex` over seeds, and a check that the cap binds (some night reaches 4 tiles only with the cap off, or the check fails with `cap` returning `roadLength`).
- **should** tools/sim/night_sim.dart:231 The gate-tile block never binds in a 3-game night (the only pre-gate stop is game 1, max 1 tile, see the must above), and no test shows it binds in any night → say so in the library doc, and cover it with the 5-game test above.
- **should** tools/sim/night_sim.dart:379 File is 379 lines against about 300 (guidelines §3), mixing the public types (NightConfig, NightResult, lines 17-105) with the night engine (`_Night`, lines 186-379) → move NightConfig and NightResult into their own file (e.g. night_types.dart), importing it from night_sim.dart.
- **should** tools/sim/night_sim.dart:136 `simulateNight` is 49 lines (guidelines §3: about 40), with the game loop, mid-ranking capture and result build in one function → move the mid-ranking capture and the result build into `_Night` helpers.
- **should** tools/sim/night_sim.dart:139 `midLeaders`, `midLast` and `firstPlazaGame` (lines 139-157) and `leaderReachedPlaza` (180) have no test, though sim-model.md steps 5 and the result section define them and the next job's metrics use them → add a test: `midLast` is the last of `rankFinal` after game `max(1, games ~/ 2)`, `firstPlazaGame` is the first game whose stop leaves a player at `roadLength`, `midLeaders` are the place-1 ids at that point.
- **should** tools/sim/night_sim_test.dart:207 "roadworks cost 0 still runs" asserts only 0..6 tiles, which the seed-range check at line 113 already does, so it passes even if `roadworksCost` is ignored → assert something the cost changes (e.g. with cost 0 some night has more `roadworksUsers` or `ownPicks` than the standard price gives on the same seeds), or drop it and say so.
- **should** docs/briefs/m17/board3b/g3d2-report.md:56 The brief's "midLeaders of game 1 on vs off are equal" check contradicts sim-model step 5 (the mid ranking follows the stop, and stops depend on decisions), and the worker dropped it instead of stopping as review rule A5 asks → Claude to decide: strike the check from the brief, or expose per-game places in NightResult and test that.
- **could** tools/sim/night_sim_test.dart:221 The champions check (221-229) recomputes place 1 with the same expression as `simulateNight` (night_sim.dart:161), so it tests the code against a copy of itself → keep it as a smoke check or drop it; no change needed for the job.
- **could** tools/sim/night_sim_test.dart:85 `main()` is about 147 lines (guidelines: functions about 40; test files have a 500-line limit) → group the checks into named functions (`checkDeterminism()`, `checkRoadworks()`, `checkKids()`).
- **could** docs/briefs/m17/board3b/g3d2-report.md:67 Self-check item 2 says "Empty night case: tested", but no test asserts an empty or zero-tile night directly; the 100-seed loops only check ranges → reword to "not tested directly" or add a zero-tile check.

## Decisions to confirm

- tools/sim/night_sim.dart:319-325 The block-clearing action is one of the Build actions limited by `tilesToBuy` (so it uses a buy slot under buildCap 3 and is paid from Bolts). sim-model step 4d can be read as paying the clear on top; the worker's reading keeps Bolts non-negative (I checked: spend = actions x tileCost <= Bolts). Why it matters: it changes how often blocked players recover.
- tools/sim/night_sim.dart:108-113 `rulesWith` takes `tileCost` as well as `roadworksCost` (sim-model names only roadworksCost). Harmless (the brief's tests need tileCost 100), but the doc says so and sim-model should be updated.
- tools/sim/night_sim.dart:278-283 "Save" leaves the last place with no build and no tile cost, and the rest of the table builds as before. Matches step 4c; no issue, listed because the worker's report does not mention it.
- The sim never ties for last (StubRoundPlacing), so the rule "roadworks to every player tied for last" is not modelled. Sim-model says so; the owner should know the sim is not the real tie rule.

## Could not check

- docs/briefs/m17/board3b/run-findings.md does not exist, so there are no runner entries on "passes on the old code" to check.
- The runner's "tests-first ok" (run.log 01:52:01) rests on a file that did not exist on the base; that proves a compile failure, not a failure for the rule's reason. I did not re-run it against the old code.
- The gate cap's effect in 5-game nights (game 2 is pre-gate there): I did not show by reading that tiles can reach 4 before the gates open, so whether the block ever binds is open.
- `tools/mine.sh` and `tools/check.sh` were not run (not in my allow list; the brief forbids mine.sh for this job).
- `dart run` of the test script needed approval in compound form; I ran `bash tools/tests/sim-test.sh` instead.

## Commit message

(none: review job, no code change)

## Status row

wave2 review of g3d2: needs one fix (gate-tile test is vacuous), two should items on split and untested fields; open: midLeaders check dropped (Claude to decide), decisions above.

## Delete

- none
