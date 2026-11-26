# night1a (B2) report

RESULT: PASS. Base 021a80da, tip see hand-back. Main line, MAX_JOBS=2.

## Jobs (all Haiku except n1b Sonnet; 1 of 7 jobs)
| job | what | turns | min | commit |
|-----|------|-------|-----|--------|
| n1a | NightFlow/NightEvent contract (night_flow.dart, 309 lines) | 21 | 4.5 | 06d8e2de |
| e0a | Arena race sets roundResult with placing (points empty on purpose, n1d decides) | 27 | 2.8 | 09fe76ec |
| e0b | Champion type: ChampionChain of ordered steps ending in shared | 20 | 4.9 | 7606176b |
| n1b | stub captionFor and full-night test (Sonnet) | 8 | 2.2 | 2571fed2 |
| f1 | race must not finish through the Bumper card (must) + tie test | 29 | 2.5 | e724a020 |
| f2 | ChampionChain unmodifiable list + pause tests | 22 | 2.5 | e0a37c02 |
| f3 | caption wording + join after scoreboard | 1* | 0 | 1d1e5cc8 |
(*usage row of the last resume only.) Ladder level 1 throughout; first run of wave 1 parked all three jobs: MY brief error (check names were package names, not check names: use host, arena). Fixed, restarted once. Class: brief. Runner restarts: 2 (plus fix round start = 3 start lines).

## Owner O1 (champion chain), answered Nov 26
"I am good with the defaults suggested." Quick night = most points, ties share the win. City Rush = closest to the Plaza, then Bolts, then shared. The owner's other option ("best place in the last game breaks a tie") is one added step: `ChampionChain([points, lastGamePlace, shared])` in packages/party_host/lib/src/night/champion.dart (quoted in the class doc). Not adopted.

## Findings
Run review 1 must / 5 should / 12 could; wave3 review 2 must (accepted: pins on old behaviour), 1 should, 3 could. Real: 1 (race finishing on the Bumper card), fixed by f1. Fixed: 5 should. Deferred (could): see REVIEW.md "Driver verdicts". Pause rules pinned as built (open design note for n1c/n1d).

## Checks and cost
- Full `bash tools/check.sh` on the tip: All checks passed (803s, 0 cached).
- job-metrics: see `bash tools/job-metrics.sh docs/briefs/m17/night1a` (11 rows, all result 0).
- agent-cost (window from 15:20): haiku $0.28, opus $0.38, sonnet $2.60; total $3.26; sonnet resumes >5m 8; inline waits >1: 3 agents (the three thumb-wait agents' own polling, not mine).
- My own calls: about 28. Waiters: thumb-wait 6 + 18 + 12 tool calls (3 agents), thumb-haiku 3 + 9 (2 agents).
- Wall time about 2 h 10 min (incl. 803 s check, lock shared with the side line).

## Fixed, unverified
None on device. Tester-visible: only the earlier home-screen search text.

## Proposed lessons (candidates, for driver-kit Proposed)
1. check: line names are suite names from `tools/check.sh --list` (host, arena), not packages; brief-check does not catch it (cost 3 parked jobs, ~15 min). 
2. A new result getter that a view treats as "round over" changes standalone behaviour: grep consumers of the getter before the brief (found only by review).
3. agent-cost --since wants an ISO local time, not epoch.

## Open items for the owner or B3
Pause rules; "place" meaning; plazaDistance unit; split night_flow.dart; n1b-report / e0b-report lack the self-check line.

## proc-sweep
proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
no background command of mine is still running
