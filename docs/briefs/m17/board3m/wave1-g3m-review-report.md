# Review of wave1-g3m (g3m): night_adapter.dart and its tests

## Summary

Verdict: small fixes

Counts: must 0 · should 5 · could 2

Top three:
1. The gap rule in Decision 1 has no test: a count-based numbering passes every test in night_adapter_test.dart (night_adapter_test.dart:23-28).
2. NightChampionDecider takes any ChampionChain but maps every points value to 0, so a points chain such as quickNight shares every win silently (night_adapter.dart:65).
3. The report says dart format ran and changed 1 file; the runner log says the worker skipped it and the hand-fix formatted it. The files are formatted now (g3m-report.md:62).

## Findings

- **should** packages/party_host/test/city/night_adapter_test.dart:23-28 No test covers a gap in recorded places (Decision 1), so a count-based numbering that gives cy=3 in this test passes the whole file → add a test with ann=3, ben=1 and cy unplaced, which must give cy=4 (count-based gives 3).
- **should** packages/party_host/lib/src/city/night_adapter.dart:65 NightChampionDecider accepts any ChampionChain but always passes points: 0, so with ChampionChain.quickNight (champion.dart:73) every entry ties and all share the win → accept only the City Rush chain, or carry points through CityChampionEntry (a City type change, Claude's call), and add a test with a points chain.
- **should** packages/party_host/lib/src/city/night_adapter.dart:17 and :52 The file holds two public types, RoundResultPlacing and NightChampionDecider; guidelines §3 says one public type per file, and the brief named this single file, so the conflict was not reported → Claude to choose: split into two files, or record the exception in the brief.
- **should** docs/briefs/m17/board3m/g3m-report.md:62 The hand-over says "dart format on both files (formatted, 1 changed)", but run.log:28 says the check failed on format and the hand-fix ran dart format, and DRIVER-NOTES.md:1 says "worker skipped dart format" → drop the claim or correct it to the runner's account; the files are formatted now (dart format --set-exit-if-changed: 0 changed).
- **should** docs/briefs/m17/board3m/g3m-report.md:20 and :62 The report says the test file has 18 tests and "18 + 5 tests"; night_adapter_test.dart runs 13 tests (5 placing, 4 decider, 2 × 2 shared contract), and 18 is the total with stubs_test.dart's 5 → state 13 for this file and 18 in total.
- **could** packages/party_host/lib/src/city/night_adapter.dart:33 The stat key 'place' is a bare string; RoundResult's stat-name doc (packages/game_kit/lib/src/round_result.dart:108-109) lists the names but not 'place' → name it in one constant or add it to that doc.
- **could** docs/briefs/m17/board3m/g3m-report.md:44 Self-check 2 says empty input is tested "for the placing with no stats"; no test passes an empty id list to placeRound, and the no-stats test (night_adapter_test.dart:30-34) lists three ids → correct the line, or add an empty-list test.

## Decisions to confirm

- Gap numbering (Decision 1, highest recorded place + 1): the brief's "placed after the placed ones" can also be read as count-based; the choice is listed but untested (finding 1).
- Equal recorded places are kept, not re-ranked (Decision 2): listed, but no test covers it.
- Points fixed at 0 (Decision 4): true for the City Rush chain, but it is a trap for any other chain passed in (finding 2).
- The two public types in one file (finding 3): the worker did not list this as a decision.
- Checks: the worker followed the brief's "never tools/mine.sh" over the task's check list, and reported it; mine.sh was not run.
- This review's report carries the brief's four sections plus the task's three closing sections (set to none, since nothing is committed or deleted); the brief says "nothing else", so Claude may want the closing sections dropped.

## Could not check

- docs/briefs/m17/board3m/run-findings.md does not exist; no entries to check.
- flutter test was not run by me. Runner evidence: run.log:45 "tests-first ok ... fails on the old code"; DRIVER-NOTES.md:1 "tests 97 pass" after the hand-fix (this covers the whole run, not only this job).
- Test-level mutation results (finding 1) were reasoned from the code, not run.
- Checks I ran: dart format --set-exit-if-changed on the two files: 0 changed; dart analyze on the two files: No issues found.

## Commit message

none: read-only review; nothing is committed.

## Status row

none: review only; the g3m job's open items are unchanged.

## Delete

- none
