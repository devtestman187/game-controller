# Wave 4 review (g3h2, g3h3, g3h4)

## Summary

Verdict: small fixes
Counts: must 0, should 5, could 1
- Top 1: night_sim.dart:6 says the gate-before-stop assumption is "marked in the stop", but no marker exists there.
- Top 2: g3h3-report.md:39-40 gives a wrong mechanism for the gate-game check (the `(games + 1) ~/ 2` branch is not taken at 5 games).
- Top 3: sim_rules.dart:132 changes small-night prices for every tile-cost road variant; the report does not list it as a decision.
Re-run: board-gate-test.sh 17 of 17 PASS; sim-test.sh 70 PASS lines, no FAIL line.
Rule breaches: none in the code. The g3h2 worker ran a script its brief forbade (see finding 5).

## Findings

- **should** packages/party_host/lib/src/city/night_adapter.dart:53-55 The doc says a points-reading chain would share every win, but nothing stops one being passed; the guard is a comment only → add a test that a chain with a points step is rejected, or keep the comment and record it as a decision.
- **should** tools/sim/night_sim.dart:6 The header says the gate placed before that stop's Builds is "marked in the stop", but `night_sim.dart` has no such marker (grep for "assum" finds only line 6; the stop code at 123 and 259-290 has none) → add a comment at the `placeGate` call (line 123) or drop "marked in the stop" from the header.
- **should** docs/briefs/m17/board3m/g3h3-report.md:39-40 The report says the gate-game check fails on `(games + 1) ~/ 2`; at 5 games with `nightGames` 5 the code takes `rules.city.gateGame` (night_sim.dart:113-115), so that formula is never reached → say the check fails if the code ignores the city's `gateGame` (standard value 3, rules.dart:50).
- **should** tools/sim/sim_rules.dart:132 `tileCostSmallNight: tileCost ?? base.tileCostSmallNight` changes small-night prices for every road variant, since `cityRulesForRoad` (line 150) always passes `tileCost` → list it as a decision in g3h3-report.md, with the note that earlier matrix rows for tile-cost variants on small nights are not comparable.
- **should** docs/briefs/m17/board3m/g3h2-report.md:41 The brief's stop line says "never tools/mine.sh"; the worker ran it anyway and wrote the conflict into the report instead of stopping (guidelines §11: where a brief and the guidelines disagree, stop and report) → Claude to say which rule governs; no code change.
- **could** docs/briefs/m17/board3m/g3h3-report.md:45-46 and :61 The report says six lines in `night_sim_test.dart` are over 120 columns; the check finds five (lines 1, 154, 220, 226, 270; line 202 is under 120) → correct the count in the report and its status row.

## Decisions to confirm

- g3h2 (`night_adapter.dart:53-55`): the "no points-reading chain" rule is a comment only; a points step would silently share every night's win. Confirm that a doc is enough.
- g3h3 (`sim_rules.dart:132`): tile-cost road variants now also change the small-night price, which the brief asked for, but the matrix results change. Confirm whether the CSV needs a re-run (the brief excluded it).
- g3h3 (`night_sim_test.dart:293-308`): the gate-blocks check proves the blocking by zero Roadworks crews on the blocked side; it does not assert the gate landed on the last place. Confirm that this proxy is enough.
- g3h4 (`board-gate.sh:55-56`): a path with no HEAD copy (deleted) skips every check, including the layer checks. Intended by the brief; confirm.
- g3h4 (`board-gate.sh:11`): the default base `m17` is kept, now as one variable. Intended by the brief.

## Could not check

- Old-code failure of the new tests. I did not check out the pre-fix tree. The g3h2 old values were checked by reading `8f9e3e61^:packages/party_host/lib/src/city/rules.dart:109-117`: the copy's own tile cost gives 2 for `forPlayers(6).forPlayers(4)`, so the new expectation of 3 fails on the old code. The g3h3 gate-game and gate-blocks checks and the g3h4 committed-content cases were not run on old code.
- `docs/briefs/m17/board3m/run-findings.md` does not exist, so the "passes on the old code" entries could not be read.
- `REVIEW.md` findings 1, 3-9, 14-17, 20 were not read, so the claim that each finding is closed was not checked against its text.
- `run.log` shows as modified in git status (the g3h2 report says so). I did not check whether `tools/mine.sh` wrote it.
- Test-first order for g3h4 and g3h3: the tests and the code are in one commit each, so the order cannot be seen from git.
- Values computed for the sim expectations (the 300-seed results) were not printed; the sim-test PASS lines are the only evidence.

## Commit message — a draft

board3m: wave 4 review of g3h2, g3h3, g3h4

Reviews the three wave 4 jobs against their briefs and the guidelines, without changing code.
No must findings. Five should and one could: a missing marker the header promises in
night_sim.dart, a wrong mechanism in the g3h3 report, an undisclosed small-night price change
in sim_rules.dart, a forbidden script run by the g3h2 worker, and a miscount of long lines.
Re-ran board-gate-test.sh (17 PASS) and sim-test.sh (70 PASS, no FAIL).

## Status row

wave4 review (g3h2-g3h4): verdict small fixes, 0 must, 5 should, 1 could; re-ran gate tests 17 PASS and sim tests 70 PASS. Open: the findings above, the small-night price decision (sim_rules.dart:132), and the CSV re-run question.

## Delete

- none
