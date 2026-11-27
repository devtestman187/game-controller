# board3a (board-1) report: City Rush board model, closed on board-line
Tip: see the last commit of this folder's closing commit (code fix e5d17b13 on top of 922e6a98). Range: 15fab9fd..tip. Result: PASS.
full check: All checks passed (227s, 8 cached). Logs: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-002657 (run.log has the line).

## Commits and jobs (Haiku workers, ladder 1 unless noted)
- g3a board types (646e5a06, rework 8c5eacbe): 11 turns. First run result 5 (analyze info; mine.sh checked 0 files): ladder 2, green.
- g3s stubs (e4f8a0be): 21 turns. First attempt result 2 (runner snapshot failed on absent sibling report: gate class).
- f3a fix round (7afeeca8): 17 turns. First attempt result 5 (flaky existing live_stats test; passes alone); unchanged retry green.
- g3b (50b963e3) superseded by the owner road model; g3b2 rework (8c5eacbe) 22 turns; g3b3 (a52abe50) main verdicts; g3b4 (343a757e) kids flag, driveCost without parameters, corner names in CityRules.
- Closing fix by hand (e5d17b13, trivial per kit step 5): see verdicts.
- Metrics: run.log METRICS lines per job (haiku workers 11-22 turns); batch wall about 20 min runner time.

## Verdicts (all findings now have one)
- Kids flag second source: FIXED. `roadworksOffered({place, lowestPlace, rules})` reads `CityRules.kidsPreset`; no second argument.
- Last-place roadworks rule: FIXED. Offered only when place == lowestPlace (ties for last all get it), never on a kids night, nobody when all tied for first. Tests: test/city/roadworks_offer_test.dart (new file). The plan does not say what a block does (own road vs rivals' roads, each player having their own road): effect NOT built, owner question below.
- New tests in existing rules_test.dart: the kids tests moved to the new file; the other g3b tests stay (file 270 lines, within limit; moving is churn). Recorded.
- Duplicate driveCost test: FIXED (removed). Corner names in assignStarts tests: FIXED (from rules.corners). Doc "players 5-8" on corners: FIXED.
- wave3-g3b2 findings (7): applied in g3b3 (verdicts in DRIVER-NOTES); weak greaterThan tests and fixture-only roadLength test: DEFERRED to code-health board3a (replace when M17b reads the values).
- wave4 findings (6): applied in g3b4. Wave5 (5): all given a verdict above.
- tools/mine.sh:161 untracked-folder gap (must): NOT fixed on board-line (shared tool); recorded in docs/code-health.md "board3a" for main.
- Worker ran mine.sh despite the brief ban: process note.

## Owner-pending
- Team-game payouts and places 5-8 (1 Bolt placeholder).
- Roadworks block effect: default proposal = a block on a tile of the placer's choice makes that tile of ANY road cost its owner nothing extra but delays them one move (not built); or simply cancel it. Owner to say which.

## Haiku-driver trial result (facts only)
- Judge (Sonnet) spawns: 6 of 6, each with a trigger (brief before runner x3, STOPPED, run REVIEW, wave-2 REVIEW).
- Driver tool calls about 90 against a cap of 60. About 10 thumb-wait and about 5 thumb-haiku spawns.
- Main stepped in: shared-road brief before the owner correction; 7 questions after g3b2; review verdicts for wave3-g3b2, wave4, wave5 after the judge budget ran out.
- Gate misses: one runner brief-gate stop (missed allow path); stale resume of g3b renamed g3b2.
- Worker ran mine.sh although the brief banned it.
- Cost: not separable by agent in a mixed window (agent-cost since 2026-11-26 21:40: total $12.49, opus $5.41, sonnet $3.73, fable $2.23, haiku $1.11).

## Release notes (final)
No visible change. Internal groundwork for the City Rush board (not in any game yet): the board's road, tile and gate types, and stand-in parts for the round placing and champion rules. Please check that nothing else changed.

## Process
- Fixed unverified: none (no device-facing change).
- Proposed lessons: 0.
- proc-sweep --since my start: 0 process(es) listed (0 orphaned flutter_tester/dart). no background command of mine is still running.
- My call count this closing run: about 17; no waiters.
