## Summary

Verdict: small fixes
Counts: must 2, should 1, could 3
1. Two groups of new tests pass on the old code: the placing tie-break (arena_race_result_test.dart:62) and the three NightFlow pins (night_flow_test.dart:91, 104, 111). The brief asked for the pins; the tie-break has no fail-first check.
2. e0a-report.md:52 still asks whether a race round in a night should wait for the results card, which is a false premise (game_screen.dart:178 forces the Bumper Round).
3. NightReason.playerLeft now reads "they went away" for every reason use, including skip and reroll captions (night_captions.dart:35); the brief asked for the phrase, but it is shared.

## Findings

- **must** packages/test_game/test/arena_race_result_test.dart:62 The new tie-break test passes on the old code, because the placing code is unchanged (f1-report.md:22 says it does not fail there). → State in the report that it pins existing behaviour and Claude accepts it, or drop it.
- **must** packages/party_host/test/night_flow_test.dart:91 The new tests at lines 91, 104 and 111 pass on the old code, since night_flow.dart is unchanged; the brief asked for these pins, so this is by design, but the review rule still counts a new test that passes on the old code as a must. → Claude accepts them as pins in the report, or drops them.
- **should** docs/briefs/m17/night1a/e0a-report.md:52 Question 2 still asks whether a race round in a night should wait for the results card, though game_screen.dart:178 forces the Bumper Round, so the premise is false. → Mark the question answered: a night forces the Bumper Round, and f1 stops a standalone race from finishing on its goal.
- **could** packages/party_host/lib/src/night/night_captions.dart:35 "they went away" is the phrase for every use of NightReason.playerLeft, so the skip and reroll captions (lines 16-17) would also read "they went away" if given that reason; no production code builds that today (grep finds tests only). → Give the leave caption its own phrase, or confirm the shared wording (see Decisions).
- **could** packages/party_host/test/night_captions_test.dart:104 The test "a player who left during a round says they went away" repeats the walk's expectation at line 50 and adds nothing. → Delete it.
- **could** docs/briefs/m17/night1a/f1-report.md:1 The report has no Summary block near its top, as run-findings.md:2 flags. → Add a Summary block.

## Decisions to confirm

- arena_view.dart:145: a standalone race now never shows a results card and plays round after round until someone leaves; confirm this is intended until the race results card (M14 b2) exists.
- night_flow.dart:279-280 (pinned by night_flow_test.dart:111): a skip or reroll during a round returns the same flow, so the round never ends through the flow; the pin calls it legal. Confirm a skipped round keeps running in the flow, or the pin fixes a wrong rule.
- night_captions.dart:35: the "they went away" wording applies to skip and reroll reasons too; the brief asked for it, but confirm the shared phrase or the separate one.
- Test files: f2 and f3 put new tests in existing files (champion_test.dart, night_flow_test.dart, night_captions_test.dart) because the briefs named them, against the rule that new tests go in a new file; confirm the briefs' choice (f2-report.md Questions 1, f3-report.md Questions 1).

## Could not check

- The fail-on-old check of arena_view_race_test.dart:48 was not run. By reading: arena_view.dart:142-145 calls onFinished on the first tick after a race goal on the old code, and 60 frames of 16 ms (0.96 s) stay inside roundBreakS = 2.0 (arena.dart:83), so it should fail there.
- No tests, analyze or format were run here (read-only job); the only test evidence is the workers' reports and run.log:87-100, which I did not check against the test output.
