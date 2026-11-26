# wave1 review (e0a, n1a, e0b): report

## Summary

- Verdict: **needs Claude**.
- Counts: 1 must, 3 should, 3 could.
- Top findings:
  1. The e0a race now sets `roundResult`, so the first goal in a standalone Arena race fires the Bumper results card (`game_screen.dart:239`). The e0a report says this happens "in a night", but a night forces the Bumper Round (`game_screen.dart:178`).
  2. The e0a tie-break test (`arena_race_result_test.dart:45`) passes on float equality, not on the id rule it claims to test.
  3. `ChampionChain` keeps the caller's mutable list (`champion.dart:63`), so its shared-last invariant can be broken after construction.
- Tests: all 3 e0a tests fail on the old code (null result). The 14 n1a tests and 13 e0b tests are new files, so they cannot pass on old code; no runner evidence was read.
- Guidelines: no lines over 120 columns in the six changed Dart files; no prints, TODOs or commented-out code found in them.

## Findings

- **must** packages/party_host/lib/src/ui/game_screen.dart:239 `_finished` now runs for a standalone race: the e0a `_result` (set at `arena.dart:202`) makes `ArenaView` call `onFinished` on the first goal (`arena_view.dart:142-146`, passed through `game_field.dart:83` and `game_screen.dart:339`), so the Bumper results card, `showResults` and `_music.roundEnded` run with zero points. The brief said no party_host change and the race's play and timing unchanged, and e0a did not stop. → Claude decides: either keep the race from finishing on `onFinished` (ArenaView finishes only on a bumper result), or accept the new race end and correct the e0a report; the report's "race round in a night" claim is wrong.
- **should** packages/test_game/test/arena_race_result_test.dart:45 expects c=2 and d=3 where c and d are equally far in y (0.14 each, by the e0a report's start values); the expectation holds on float rounding or on the id tie-break, so the test does not prove the tie-break its name implies. → Give c and d distinct distances in the test, or add a separate tie test with equal distances.
- **should** packages/party_host/lib/src/night/champion.dart:63 the constructor stores the caller's list (`final List<ChampionStep> steps;` at line 78), so `steps.add(ChampionStep.points)` after construction breaks the asserted invariant (shared last, only there) silently. → Store `List.unmodifiable(steps)` in the initialiser list and keep the two asserts on the parameter.
- **should** packages/party_host/lib/src/night/night_flow.dart:273 the pause decisions have no test: `NightRoundEnded` is legal during a pause and clears it (line 274, via `_move` default `paused: false`), and skip and reroll are legal while paused (lines 279-280). The n1a report lists both as decisions, and the self-check says "pause with round end (decision above)" as if covered. → Add two tests in night_flow_test.dart: pause then round end gives `roundEnd` with `paused` false; skip during pause keeps `paused` true.
- **could** packages/party_host/lib/src/night/night_flow.dart:1 the file is 309 lines against the brief's "about 270 at most" and holds 14 event classes plus the state machine (two responsibilities). → Move the `NightEvent` hierarchy and the two enums to `night_event.dart` if Claude allows a new file.
- **could** packages/party_host/test/night_flow_test.dart:88 the test "a skip at the scoreboard is illegal" checks the howTo stage of a different flow (line 90), which is not about the skip. → Remove lines 88 and 90 from that test, or give the howTo check its own test.
- **could** packages/test_game/test/arena_race_result_test.dart:55 the e0a report says only the first and second tests fail on old code; the third also fails there, because `roundResult` is null after the goal. → Correct the sentence in e0a-report.md (the report is outside this review's allow list; Claude decides).

## Decisions to confirm

- e0a: the race's placing ties by id, and points are empty by design (`arena.dart:212-227`); the race's `draw` is left at its default `false`.
- e0a: a race's first goal now ends the round through the results card (see the must finding). This is a behaviour change the brief did not ask for.
- e0b: `ChampionChain` is not `const` (`champion.dart:63`), against the brief's "const constructor"; the worker's reason (Dart cannot check list contents in a constant) matches the `invalid_constant` failure it reports, but I did not re-run it.
- e0b: `champions` treats an all-null step as a tie that keeps everyone (`champion.dart:96-98`); no test covers that path except the City Rush null case with bolts.
- e0b: the scoreboard pin compares `row.total`, not points; the `threeAwards` award points therefore do not show in the comparison (`champion_test.dart:100`).
- n1a: `NightSetup` is legal again while in setup (`night_flow.dart:268`); the brief gave no flag, so a second setup is accepted.
- n1a: `NightEnded` is legal only from ceremony (`night_flow.dart:278`); no early end exists, as the report's question 2 says.
- n1a: round end clears pause, and skip, reroll and the doubled announcement work during a pause (see the should finding).

## Could not check

- docs/briefs/m17/night1a/run-findings.md does not exist, so there is no runner evidence on "passes on the old code" beyond the reports.
- docs/briefs/m17/night1a/run.log, probe-e0b.patch and probe-n1a.patch were not read (not in the brief's read list, or not needed for the findings).
- Whether a standalone race reached `_finished` before this change: `game_screen.dart` was read only at `_finished` (239), `_start` (178) and the race comment (359); the full game-screen path was not traced.
- The e0a start positions (slot y values) and the testMap geometry were not re-derived; the expectations were checked against the report's values only.
- `threeAwards` and `NightState.rows` (the e0b pin) were not read; the claim that the award points do not change the pin is unverified.
- `docs/coding-guidelines.md` and `docs/review-rules.md` were checked through the worker extract, not the full files.
- No tests were run, to keep this job read-only.

## Commit message — a draft

None: this review changes only its report. Nothing to commit.

## Status row

wave1 review (e0a, n1a, e0b): done, needs Claude: 1 must (a standalone race now finishes on its first goal via the results card), 3 should, 3 could; open: the must decision, the tie test, the champion list invariant and the pause tests.

## Delete

- none
