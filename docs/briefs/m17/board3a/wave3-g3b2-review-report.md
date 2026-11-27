# Review of g3b2 (board3a, CityRules rework)

## Summary

Verdict: **small fixes**
Counts: must 0 · should 3 · could 4
Top three:
1. The rule that a gate is only valid on a tile before the Plaza has no test (board.dart:75-77).
2. The per-game earn, buy and pay loop lives only in a test helper, so the worked examples test the test (rules_test.dart:166-178).
3. `gatesOpen` is kept state with no reset and no stated lifetime (board.dart:87-96).

## Findings

- **should** packages/party_host/lib/src/city/board.dart:75-77 The branch that refuses a gate on the Plaza or at a negative index has no test; board_test.dart only tests a gate on an off-board road → add a test with tileIndex equal to the Plaza index and one with -1, each expecting ArgumentError.
- **should** packages/party_host/test/city/rules_test.dart:166-178 The helper `tilesAfterEachGame` holds the per-game sequence (add Bolts, buy with tilesToBuy, pay with tileBuildCost); no lib function owns it, so the worked examples at lines 180-196 would still pass if the game's real loop differed → move the loop into rules.dart as a function and test it there.
- **should** packages/party_host/lib/src/city/board.dart:87-96 `_gatesOpen` is set by `openAllGates()` and never reset; a Board kept for the night stays open for every later round → state the Board's lifetime in the doc comment and add a reset, or confirm one Board per night and say so in the doc.
- **could** packages/party_host/test/city/rules_test.dart:74-84 The `saveBonus` and `buildCap` tests assert only `greaterThan(0)`; no lib function reads `saveBonus` (rules.dart:48 is the only use) → drop them, or test the rule that uses the value once it exists.
- **could** packages/party_host/test/city/rules_test.dart:86-94 The roadLength test builds its own road and checks that road's length, so it tests the fixture, not CityRules → remove it or check the length through Board.
- **could** packages/party_host/test/city/board_test.dart:171-178 The tile-id uniqueness expectation repeats the check Board's constructor already makes (board.dart:65-66) and that `_cityBoard` runs on every call → keep only the lane-count expectation on line 179.
- **could** packages/party_host/test/city/rules_test.dart:14 The bare literal `3` in `3 * rules.tileCost` is not a named value → use a local named count, e.g. `const tilesBought = 3`.

## Decisions to confirm

- Dropped `CityRules.kids` and the `roadworks` flag (rules.dart, removed from the old file): no user outside `city/` (grep of `packages` and `apps`), so safe; confirm the kids preset is not wanted.
- `driveCost` charges `roadworksCost` (1 Bolt) on a road not built yet (rules.dart:100-102): the brief only said built roads cost 0; confirm the 1 Bolt.
- `rankFinal` keeps input order for ties (rules.dart:116-123): the result depends on the caller's list order; confirm that is the intent.
- The player-to-road mapping (players 1-4 on corners, 5-8 on lanes) exists only in the test builder `_cityBoard` (board_test.dart:17-27); no lib code assigns it. Confirm who assigns it.
- Team-game payouts were not added; places 5-8 are 1 Bolt placeholders (rules.dart:27-28). Owner-pending, as the report says.
- "Early arrival does not end the night" has no function and no test (g3b2-report.md:34-35). The brief asked for the order test only; confirm that is enough.
- The worker ran `tools/mine.sh` although the brief said never to (g3b2.md step 8; g3b2-report.md:46-48). Process point for Claude.

## Could not check

- Test, format and analyze results: not run (read-only job). The report's "OK 44 tests packages/party_host" equals the sum of the 18 and 26 tests in the two touched files, so the package-wide total is unverified.
- Tests-first order: the diff is one range with no per-step history.
- Whether the new tests fail on the old code: not run.
- `docs/briefs/m17/board3a/run-findings.md`: does not exist.
- Callers outside `packages/`: `apps/` was searched for imports of `city/board.dart` and `city/rules.dart` and none were found; no other directory was searched.

## Commit message

```
review: g3b2 CityRules rework (board3a)

Read-only review of the g3b2 job against its brief, the coding guidelines
and the review rules. Findings: gate tile validation untested, the
per-game build loop only in a test helper, gatesOpen has no reset or stated
lifetime, and three weak or redundant tests. No code changed.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row

g3b2 review: small fixes (0 must, 3 should, 4 could). Open: gate-tile validation test; move the per-game build loop into rules.dart; gatesOpen lifetime; three weak or redundant tests and one magic literal; 8 owner decisions (kids preset, driveCost 1 Bolt, rank ties, player-to-road mapping, team payouts, early arrival, one Board per night, mine.sh use).

## Delete

- none
