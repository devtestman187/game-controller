# Wave 1 review (g3r1, g3t): report

## Summary

Verdict: **small fixes**
Counts: 2 must, 1 should, 4 could.
Top three:
1. `gateTileIndex` is still in `rules.dart` and its copies; brief g3r1 item 2 is not done. The blocker the g3r1 report gave (`board_test.dart`) went away with g3t.
2. The gate-tile test in `rules_test.dart:161` tests a local value, not the code, so it passes on any rules.
3. `forPlayers` prices a copy from its own `tileCost`, so a chained call gives the wrong price (documented, but a trap).

## Findings

- **must** packages/party_host/test/city/rules_test.dart:161 The test "the gate tile is on the road, before the Plaza" checks `roadLength - 2` against constants; it never reads the code, so it passes on any rules → delete it together with `gateTileIndex`.
- **must** packages/party_host/lib/src/city/rules.dart:91 `gateTileIndex` (doc 91-92, field 93, constructor 30, `standard` 51, copy 126) is still there, though brief g3r1 item 2 says delete; its doc describes the fixed corner gate that g3t removed, and no lib code reads it → delete the field, its doc and its uses at rules.dart:30, 51, 126, rules_test.dart:19 and 80, roadworks_offer_test.dart:18, tools/sim/sim_rules.dart:125 (all in the g3r1 allow list; board_test.dart no longer uses it, checked by grep).
- **should** packages/party_host/lib/src/city/rules.dart:115 `forPlayers` sets `tileCost` from `this.tileCost`, so `CityRules.standard.forPlayers(6).forPlayers(2).tileCost` is 2, not 3 → keep the 3-Bolt base in its own field (for example `tileCostSmallNight`) and choose from it in `forPlayers`, so any copy can be re-priced.
- **could** packages/party_host/test/city/rules_test.dart:145 The test "the standard cap is 3 Builds per stop" and the test "a night plays 5 games" (line 172) pin literal config values and pass whatever the rules do → keep them as config pins, or drop them; decide with the owner.
- **could** packages/party_host/test/city/rules_test.dart:7 and packages/party_host/test/city/roadworks_offer_test.dart:6 The 15-field `CityRules(...)` copy is written twice (and again in tools/sim/sim_rules.dart:113); each new field must be added in three places → one shared test helper, or `copyWith` if the owner agrees to a new method.
- **could** packages/party_host/test/city/rules_test.dart:68 The test "keeps every other field and the kids flag" does not check `tileCostLargeNight` or `largeNightFrom`, so dropping either from `forPlayers` passes → add those two expects.
- **could** docs/briefs/m17/board3m/g3r1-report.md:17 The report says the roadworks tests "moved to the roadworks file"; the two `roadworksPrice` tests were deleted, not moved (roadworks_offer_test.dart has no price test) → correct the sentence.

## Decisions to confirm

- rules.dart:182 `nextTileGated` defaults to `false`, so a caller that omits it is offered roadworks on a gated tile. The brief asked for the default; confirm, or make it required (no other caller exists yet).
- rules.dart:109-131 `forPlayers` is "call on the base" (worker's decision, listed in its report). See the should finding; the owner's rule does not need this, so the fix is safe to make.
- rules.dart:194 `gateTargets` does not exclude a rival whose next tile is gated. Safe only because `gateOffered` returns false once a gate exists; the gate-game caller must check `gateOffered` first.
- rules.dart:13 new public typedef `GateRoad`, not in the brief's list. It is listed in the report, so not hidden; low risk.
- board.dart:86-98 `placeGate` checks road and tile before the one-gate rule, so a refused call leaves the board unchanged. Safe, and tested (board_test.dart "places nothing").
- Process: g3r1 and g3t both ran `tools/mine.sh`, while their briefs' stop lines say "never tools/mine.sh" (the workers' own rules say to run it). Decide which governs.
- Later (review rules A3): `placeGate` and `openGate` are not called anywhere yet. Pause, host away, player away, Get ready, dropped link, results and leaving are untested for the gate; the gate-game job must cover them.

## Could not check

- No test or analyzer run (read-only job). `docs/briefs/m17/board3m/run.log` lines 12 and 14 show only "result 0", without test counts, so the reports' "OK 75" (g3r1) and "OK 79" (g3t) are unverified.
- "Fail on the old code": the new tests use an API the old code does not have, so they cannot be run against it; not checked.
- `docs/briefs/m17/board3m/run-findings.md` does not exist, so no runner findings were read.
- `tools/tests/sim-test.sh` was not read or run; `tools/sim/sim_rules.dart` was read from the diff only.
- Grep (done): no lines over 120 columns and no print, TODO, BISECT or ignore in the city lib and test files.

## Commit message — a draft

review: wave 1 (g3r1, g3t) review report

Read-only review of the g3r1 and g3t commits against their briefs, the coding guidelines and review rules. Adds the report only. Findings: gateTileIndex was not removed (brief g3r1 item 2), a gate-tile test asserts nothing, and forPlayers prices a copy from its own tileCost.

## Status row

board3m wave 1 review (g3r1, g3t): report written, verdict small fixes (2 must, 1 should, 4 could). Open: delete gateTileIndex and its uses, fix the gate-tile test, fix forPlayers re-pricing; decisions on nextTileGated default and the tools/mine.sh conflict.

## Delete

- none
