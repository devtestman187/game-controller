# night1c f1: the night controller ends with the night; the resumed test uses the fake scheduler

## Summary

- `nightFlowControllerProvider` now selects `null` once the night `isOver`. `NightState.isOver` is `isEndedEarly || round >= rounds`, so an early end (`endNow`) and the last round both drop the controller. The roster listener is unchanged.
- The provider test gains two tests (early end, last round) that fail on the code as it was and pass now.
- The resumed-controller test now overrides `nightScheduleProvider` with a fake scheduler and asserts the armed scoreboard pause instead of leaving a real 8 s Timer.
- The fake scheduler is copied into the provider test file: the brief's allow list does not include `night_flow_controller_test.dart` or `support/night_harness.dart`.
- Decisions: the early-end test also checks that disposing drops the armed pause (`clock.waiting` 0); the last-round test records three rounds of 3 points each on a three-round night.

## Files changed

- `packages/party_host/lib/src/night/night_flow_provider.dart`: the `partyNightProvider` select returns `null` when the night is over (ended early included). Doc comment says the controller is built again when a night starts or is over.
- `packages/party_host/test/night_flow_provider_test.dart`: new `_clockContainer`, `_FakeTimer`, `_FakeScheduler`; the resumed test uses the fake clock and asserts `clock.asked == [scoreboard]` and `clock.waiting == 1`; two new tests (early end via `endNow`, last round via `recordRound`), each asserting the provider is null and that a later `next()` on the old instance adds no event.
- `docs/briefs/m17/night1c/f1-report.md`: this report.

## Checks

- Tests-first: before the provider change, `tools/mine.sh` failed exactly the two new tests (`Expected: null, Actual: <Instance of 'NightFlowController'>`). The resumed test passed on the old code, as expected for a test-only change.
- After the change: `tools/mine.sh` → `OK 12 tests packages/party_host`, `RESULT: ok` (run three times, including after the doc-comment edit; the script reformatted the two files).
- `dart analyze` on the two changed files: `No issues found!`
- Line counts: provider 32, test file 144.
- `tools/check.sh` not run (per brief).

## Self-check (review-rules part A)

1. Host setups: the provider is host-side only; covered by the provider tests (no TV/phone host setup change).
2. Kept state starts and ends: starts at `start`, ends at `end`, early end, or last round; test "ending the night early…" and "playing the last round…" show null and the disposal. Nothing going on: "there is no controller while no night runs" (unchanged, passes).
3. Combinations: the pause menu, host away, "Get ready", dropped link, results and leaving were not touched; no test covers them here.
4. Stayed inside the allow list: yes (the two files plus this report).
5. Stop rather than overstep: see question 1; nothing was stopped.
6. Looks: no UI change, no look-sized widget.

## Commit message — a draft

Subject: `party_host: night controller ends when the night is over`

Body:
- The night controller provider returns null as soon as the night isOver,
  ended early included, so the controller is disposed and stops
  auto-advancing after the host ends the night (endNow).
- Previously the select watched only the night's length, so an early end
  never rebuilt the provider.
- The resumed-controller test uses a fake scheduler and asserts the armed
  scoreboard pause instead of a real 8 s Timer.
- The fake scheduler is copied into the provider test file.
- Two new tests (early end, last round) fail on the old code and pass now.

## Status row

night1c f1 done: the night controller provider drops its controller when the night is over (early end included), with two new tests; the resumed test uses the fake scheduler. Open: the final ceremony may no longer auto-advance after the last round (question 1); the existing "ending the night" test still uses a real Timer.

## Delete

- none

## Questions and suggestions (not acted on)

1. Risk: the controller is now disposed when the last round is recorded (`isOver` becomes true), before the final ceremony (`NightCeremony`, then `NightEnded`) has run. The controller arms those steps on its own timers, so they may never fire. `night_scoreboard_screen.dart:69` holds the old instance it read at start. No test here covers the final ceremony through the provider. Please decide: keep the controller until `NightEnded`, or dispose on `isOver` as the brief says and drive the ceremony some other way.
2. Suggestion: the existing test "ending the night disposes the controller…" still uses a real `Timer(after, fire)`. It could use `_FakeScheduler` too, to remove the last real timer from this file.
3. Suggestion: the provider doc comment still refers to the night "starting or ending" in its first sentence; I only edited the end of it to say "or is over". A wider rewrite was not needed for this job.
