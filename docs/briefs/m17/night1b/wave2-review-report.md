# wave2 review: n1d (commit b4459fef, read-only)

## Summary

Verdict: small fixes
Counts: must 0, should 1, could 3
1. should: docs/briefs/m17/night1b/n1d-report.md:9 says "6 tests"; night_scoring_test.dart has 8 `test(` calls.
2. could: packages/party_host/lib/src/night/night_state.dart:290 award points enter `rows` totals, and no test covers a player with an award.
3. could: packages/party_host/test/night_scoring_test.dart:57-66 repeats the tie case of champion_test.dart:97-111.

## Findings

- **should** docs/briefs/m17/night1b/n1d-report.md:9 says the test file has "6 tests" (and the Status draft at line 59 repeats "6 tests"); the file has 8 `test(` calls (lines 12, 17, 23, 29, 46, 57, 68, 79) → change both counts to 8.
- **could** packages/party_host/lib/src/night/night_state.dart:290 `rows` adds `awardPoints * awardsWonBy(id)` to each total, which `championsAmong` reads through `row.total`; no test in night_scoring_test.dart gives a player an award, so this path is unpinned while the report says "the +3 award points count" (n1d-report.md:14) → add one case with an awarded player and check the champion and `place == 1` agree.
- **could** packages/party_host/test/night_scoring_test.dart:57-66 is the same tie-for-first case as champion_test.dart:97-111 (which already compares `ChampionChain.quickNight` with place 1) → keep it if the brief's (d) list needs it; otherwise drop it, or say in the file doc that the provider-level test is the other half.
- **could** docs/briefs/m17/night1b/n1d-report.md:8 calls `championsAmong` a "getter"; night_state.dart:315 declares it as a method with a `players` parameter → write "method" in the report.

## Decisions to confirm

- night_state.dart:315 takes `players` and reads `rows(players)`, so the champion counts award points and the leaver's row (night_state.dart:285-309). That matches the brief and the scoreboard, but the owner should confirm that award points count toward the Quick night champion.
- `championsAmong` has no lib caller yet (grep of packages/party_host/lib: only its definition at night_state.dart:315). The report says so (n1d-report.md:44); the owner should confirm the wiring is the next job, not this one.
- The brief's "fails on the base" for test (d) holds only by a compile error (n1d-report.md:17); no test shows the behaviour failing on the old code. Accept, or ask for a behavioural check.

## Could not check

- docs/briefs/m17/night1b/run-findings.md does not exist, so there are no runner entries on "passes on the old code" for this job.
- I did not run the tests, `dart analyze` or `tools/mine.sh` (this is a read-only job). The "26 tests" and "No issues found" claims in n1d-report.md:30-31 are unverified.
- I did not open docs/coding-guidelines.md or docs/review-rules.md in full; the rules I checked are the worker extract in my instructions (size, names, magic numbers, leftovers, self-check part A). Review-rules part B was not checked.
- The harness helpers (`nightPlayer`, `roundResult`, `withChaos`, `threeAwards` in test/support/night_harness.dart:12-50) were only checked by signature, not read in full.
- The report's self-check claims for pause, party night, reconnect and "Get ready" were judged from the diff: no UI or flow code changed in this job, so they hold by absence.

## Commit message

docs: wave2 review of n1d (findings only)

Review of commit b4459fef (n1d: championsAmong and the scoring pins) against
its brief and the coding rules. No code changed. Findings: the n1d report
counts 6 tests where the file has 8; the award points in the champion's
totals have no test; one tie test repeats champion_test.dart.

## Status row

wave2 review of n1d: small fixes. Done: read the diff, brief and report; findings written. Open: n1d-report.md test count (6 → 8) and the award-points test; tests not re-run by this review.

## Delete

- none
