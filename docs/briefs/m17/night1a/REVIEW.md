# night1a run review

## Summary

- Verdict: **needs Claude's design**. One must needs a decision before any fix; the rest is one fix batch, split as in the sizing note.
- Counts: 1 must, 5 should, 12 could (18 findings). No per-job finding was fixed in the run; all 13 carried-over findings still hold in the final code.
- Carried over: all 7 wave1 findings, all 6 wave2 findings, and the one run-findings line (merged into the wave2 self-check finding). No REVIEW-VERDICTS.md and no f<n> fix job exist.
- Top five:
  1. A standalone Arena race now ends on its first goal through the Bumper results card (`game_screen.dart:239`, fed by `arena_view.dart:142-146`). The e0a report's "race round in a night" is wrong: a night forces the Bumper Round (`game_screen.dart:178`).
  2. `ChampionChain` keeps the caller's mutable list (`champion.dart:63`, `:78`), so the shared-last invariant can break after construction.
  3. The race tie-break test (`arena_race_result_test.dart:45`) uses two players at equal distance, so it does not prove the id rule.
  4. Pause decisions in `night_flow.dart:273-274` and `:279-280` have no test.
  5. Two reports lack the part A self-check: `n1b-report.md:1` and `e0b-report.md:37`.
- Sizing: no finding is pinned by a controller_app test (grep of `controller_app/` for these files and for the race result found none). Fix jobs are listed under Findings.
- Questions only the owner can answer: see Open questions (the first two block the must and the pause tests).

## Findings

- **must** packages/party_host/lib/src/ui/game_screen.dart:239 `_finished` runs for a standalone race: `ArenaView` calls `onFinished` as soon as `roundResult` is non-null (`packages/test_game/lib/src/arena_view.dart:142-146`), so the first goal shows the Bumper results card, calls `showResults` and `roundEnded` with zero points. The e0a brief said no party_host change and the race's play and timing unchanged (`e0a.md:3`). → Claude decides first: either ArenaView finishes a race only on a bumper result (test_game change, plus a test in `arena_view_test.dart`), or accept the new race end and correct `e0a-report.md:10`. (from: e0a)
- **should** packages/party_host/lib/src/night/champion.dart:63 the constructor stores the caller's list (`final List<ChampionStep> steps;` at `:78`), so `steps.add(ChampionStep.points)` after construction breaks the asserted invariant silently. → Store `List.unmodifiable(steps)` in the initialiser and keep the two asserts on the parameter. (from: e0b)
- **should** packages/test_game/test/arena_race_result_test.dart:45 c and d are equally far from the goal centre (|dy| 0.14 each, `e0a-report.md:24`), so `c: 2, d: 3` holds by float rounding or by the id rule; the test does not show the tie rule its name claims. → Keep the distinct-distance test as it is and add one test that puts two players at exactly equal distance on purpose and asserts id order. (from: e0a)
- **should** packages/party_host/lib/src/night/night_flow.dart:273-274 and `:279-280` a round can end while paused (`_move` default `paused: false`), and skip and reroll are legal while paused; no test covers either (the pause tests are at `night_flow_test.dart:31-34` and `:93-99`). → Add two tests in night_flow_test.dart: pause then round end gives `roundEnd` with `paused` false; skip during pause keeps `paused` true. (from: e0a/n1a wave1)
- **should** packages/party_host/test/night_captions_test.dart:9 the full-night walk has one join, at round 0; no join after a scoreboard is folded or captioned, though brief item (a) asks for one. → Add `NightPlayerJoined('a2', 1)` after line 17 (legal at scoreboard 1) and `'Avatar a2 joined at round 1'` to the expected list. (from: n1b)
- **should** docs/briefs/m17/night1a/n1b-report.md:1 and docs/briefs/m17/night1a/e0b-report.md:37 neither report has the review-rules part A self-check (n1a's has one at `n1a-report.md:59`); n1b-report.md also has no Summary block (run.log:56). → Add the six-line self-check, each with its test, to both reports. The wave2 review rated the n1b gap must; I rate it should because no code is affected. (from: wave2, across jobs)
- **could** packages/party_host/test/night_flow_test.dart:88-90 the test "a skip at the scoreboard is illegal" asserts `flow.stage` of a different flow (`:90`, built at `:88`). → Remove lines 88 and 90, or give the howTo check its own test. (from: e0a/n1a wave1)
- **could** packages/party_host/lib/src/night/night_captions.dart:8 a legal one-round night shows "Tonight: 1 rounds" (`NightFlow.start` asserts only `rounds > 0`, night_flow.dart:245). → Use "round" when n is 1, with a test. (from: n1b)
- **could** packages/party_host/lib/src/night/night_captions.dart:20 a join during setup reads "Avatar a1 joined at round 0" (the test expects it at `night_captions_test.dart:42`). → Say "before round 1" when r is 0. (from: n1b)
- **could** packages/party_host/lib/src/night/night_captions.dart:32 "Avatar a1 left at round 1: a player left" repeats "left". → Give `NightReason.playerLeft` a phrase that does not repeat the verb. (from: n1b)
- **could** packages/party_host/lib/src/night/night_captions.dart:7 the brief's changes line names "NightCaptions · captionFor" (`n1b.md:4`), but the code has only a top-level `captionFor`, which step 1 asks for (`n1b.md:10`); the report does not record the choice. → Claude keeps the top-level function and rewords `n1b.md:4`; the n1b report records it. (from: n1b)
- **could** packages/party_host/lib/src/night/night_flow.dart:1 the file is 309 lines, over the 300 guideline and over the brief's target (`n1a-report.md:73`; see Numbers). → Move the `NightEvent` hierarchy and the two enums to `night_event.dart`; this needs Claude to allow a new file. (from: n1a)
- **could** packages/party_host/lib/src/night/champion.dart:41 `plazaDistance` is a distance with no unit in its name ("in the game's own units"; the guideline asks for units in names). → Name the unit once the Plaza's unit is known (or ask the owner); no change until then. (from: e0b)
- **could** packages/party_host/lib/src/night/night_flow.dart:95 and champion.dart:23 booleans do not ask a question: `lastRound` (also at `:119`, `:133`) and `higherWins`. → Ask the owner whether the PRD names `lastRound`; if not, rename to `isLastRound`-style names across the five event classes and NightFlow. (across jobs)
- **could** packages/party_host/test/champion_test.dart:100 and packages/party_host/lib/src/night/night_state.dart:306 the champion chain and the scoreboard's place 1 are two implementations of the same shared-tie rule; the pin test is the only link. → Before wiring, make one of them the source for the other. (across jobs)
- **could** packages/test_game/lib/src/arena.dart:202 and night_state.dart:306 "place" means two things: the race gives distinct places (ties broken by id, `arena.dart:216-217`), the scoreboard shares places on a tie. → Decide one meaning before n1d turns place into points. (across jobs)
- **could** docs/briefs/m17/night1a/e0a-report.md:48 says only the first and second race tests fail on the old code; the third also fails (`arena_race_result_test.dart:55`, since `roundResult` is null after the goal). → Correct the sentence in the report. (from: wave1)
- **could** docs/briefs/m17/night1a/n1b.md:8 and n1b-report.md:3 "tests-first: exempt" for a new consumer; G9 allows exempt only for a pure refactor or docs job. The runner ran tests-first anyway and the test failed on the old code (run.log:52), so the proof exists. → Note it in the status row; no code fix. (across jobs)

Fix-job sizing (no phone-pinned finding; one wave unless noted):
- Job A (needs Claude's decision): the must. Files: game_screen.dart or arena_view.dart; plus `e0a-report.md:10`.
- Job B: champion.dart (one finding).
- Job C: arena_race_result_test.dart (tie test) and `e0a-report.md:48` (two findings, two files).
- Job D: night_flow_test.dart (pause tests and the skip test: two findings, one file).
- Job E: night_captions.dart and night_captions_test.dart: wording (`:8`, `:20`, `:32`, three lines) in one job; the join test is a separate job in a later wave, because both edit night_captions_test.dart.
- Job F: n1b-report.md and e0b-report.md (self-check; two files, one finding).
- Decisions first, not jobs: the naming, unit, place and night_flow split items.

## Open questions

1. Should a standalone race end on its first goal through the results card (must above)? Safest: no; keep the race from finishing through `roundResult` until decided.
2. Should a second NightSetup be illegal (n1a Q1)? Safest: yes, with one flag; `night_flow.dart:268` accepts it today.
3. Should a night end early on no players, host away or a dropped link (n1a Q2)? Safest: no change now; NightEnded stays legal from ceremony only.
4. Should a round be allowed to end while paused (n1a Q3)? Safest: yes, as built, so a time-up cannot stick.
5. Should skip, reroll and the doubled announcement be blocked during a pause (n1a Q4)? Safest: block them, so a paused round does not change.
6. Is ChampionChain's non-const constructor accepted (e0b decision 1; brief said const)? Safest: accept; Dart cannot check list contents in a const.
7. Is the champion type kept out of `party_host.dart` until wiring (e0b decision 5)? Safest: yes.
8. Are avatar ids codes and never nicknames (`night_flow.dart:45-46`; `Avatar <id>` in captions)? Safest: confirm the id format before the TV shows them.
9. Does `row.total` include award points (`champion_test.dart:100`; e0b says they do not change the pin)? Safest: pin on the number the night will show; not read in this review.
10. Were the runner's brief edits intended (n1a target "under 250" changed to "about 270 at most"; check names `party_host`→`host`, `test_game`→`arena`; turns 35→45)? Safest: keep them; the n1a file still misses the new target.
11. May night_flow.dart split into a new `night_event.dart` (could, above)? Safest: yes, if the split is its only change.

## Numbers against targets

- night_flow.dart: 309 lines. Misses the n1a brief's "under 250" (original, `n1a.md` at the base commit) and the edited "about 270 at most"; over the 300 guideline; under the 380 limit. Target missed.
- Other changed lib files: arena.dart 246, champion.dart 113, night_captions.dart 35 lines. Within 300.
- Test files: 13 champion (report says 13), 14 night_flow (report says 14), 4 captions (report says 4), 3 race (report says 3). Counts match the reports.
- Columns: no changed Dart file has a line over 120 (grep for 121 or more characters; the only hits are in untouched test files).
- Race clear test: 121 frames (ceil(2.0 × 60) + 1), from `e0a-report.md:26`. Recomputed from the brief's 2.0 s break; matches.
- Turns: e0a and n1a were capped at 35 and parked, then re-run after the brief's cap became 45 (run.log:13-16). n1b logged 8 turns in 5 min wall (run.log:50); its real turn count is unknown.
- No ms or time targets appear in the reports, and STATUS.md does not exist, so no status targets were checked.

Hand-fixes: none. run.log has no HAND-FIX line and there is no hand-fix job. Tests-first proof exists for all four jobs (run.log:37-39 and :52); reports exist for e0a, n1a, e0b and n1b, plus both wave reviews.

Unverified fixes: none found. Every changed behaviour has a tests-first or mine.sh record, but the must's effect on the TV is read only (no device check).

## Could not check

- No analyze or test was run, because this job is read-only; the run's evidence is run.log and the reports.
- The race tie: the float values of c's and d's distances were not computed; the testMap slot positions were taken from e0a-report.md:22-24 and not re-derived.
- Existing tests that pin `onFinished` for a race (arena_view_test.dart, arena_session_test.dart) were not read; whether they pass with the must is unknown.
- `threeAwards`, the award points and `NightState.rows` were not read beyond the pin lines (night_state.dart:278-306 for the place rule only); the claim that awards do not change the pin is unverified.
- docs/coding-guidelines.md and docs/review-rules.md were checked through the worker extract, not the full files.
- The parked first attempt (e0a, n1a, e0b: parked-*.patch and flash-<job>.log) is not in the folder; not read.
- Stale probe patches (probe-e0b.patch, probe-n1a.patch) are still in the folder; their use was not checked.
- The device behaviour of a race ending on its first goal, and the TV look of the new captions, were not checked (no device).
- The n1b model in run.log (sonnet, run.log:49) differs from the other jobs (haiku); whether that matters was not judged.

## Commit message — a draft

Review the night1a run: one must, five shoulds, twelve coulds

Read-only review of the night1a run (e0a, n1a, e0b, n1b) as one change.
The must: a standalone Arena race now ends on its first goal through the
Bumper results card, which needs Claude's decision. Shoulds: a mutable
champion list, a tie test with equal distances, untested pause decisions,
a caption join test, and missing part A self-checks in two reports.
Report only; no code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

night1a run review: done, needs Claude (1 must: a standalone race ends on its first goal via the results card; 5 should; 12 could). Open: the must's decision, the champion list, the race tie test, the pause tests, the caption join test, the self-check in two reports.

## Delete

- none
