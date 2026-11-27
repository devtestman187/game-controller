# night1c wave-3 review: f1 and f2

## Summary

Verdict: **needs Claude**
Counts: must 1 · should 1 · could 2
1. The provider drops the controller when the last round is recorded, so the final ceremony and `NightEnded` never fire (night_flow_provider.dart:19).
2. A real `Timer` is still armed in the pre-existing "ending the night disposes" test (night_flow_provider_test.dart:128).
3. The fake scheduler is a third copy of the same fake (night_flow_provider_test.dart:42).
Not run: tests and analyze (read-only review). The "fails on the old code" claim for the two new tests is unverified; no run-findings.md exists.

## Findings

- **must** packages/party_host/lib/src/night/night_flow_provider.dart:19 The select returns null as soon as `isOver`, and `isOver` is `round >= rounds` (night_state.dart:220), so the last round's recording disposes the controller (line 27) and cancels the pending scoreboard step that `_armScoreboard` arms (night_flow_controller.dart:308-309); `NightCeremony` and `NightEnded` are then never applied. → Keep the controller until its flow has ended (ended early, or `NightEnded` applied), and add a provider test that after the last round `next()` still applies `NightCeremony` and `NightEnded`.
- **should** packages/party_host/test/night_flow_provider_test.dart:128 The pre-existing "ending the night disposes the controller" test arms a real `Timer(after, fire)` (lines 128-131), against the no-real-time rule, and the job left it in the file it touched. → Use `_clockContainer` with `_FakeScheduler` and assert `clock.waiting`, as the new tests do.
- **could** packages/party_host/test/night_flow_provider_test.dart:42 `_FakeScheduler` and `_FakeTimer` are a third copy; the same fakes are at night_flow_controller_test.dart:9-36 and night_controls_test.dart:11-34. → Move one shared fake into `test/support/` in a later job; the brief allowed the copy for now.
- **could** packages/party_host/test/night_settings_test.dart:109 `await pumpEventQueue()` waits on event-queue timing, not on the write (also lines 121 and 131). → Read the saved value after `await container.read(prefsProvider).reload()`, the brief's first option, and fall back only if it fails.

## Decisions to confirm

- night_flow_provider.dart:19: disposing at `isOver` follows the brief literally but drops the final ceremony path; the worker raised it as a question and did not list it among its decisions. Needs Claude's call (see the must).
- night_settings_test.dart:109: `pumpEventQueue` was used instead of the brief's `reload()` option; the reason given is only "simpler".
- night_settings.dart:200: `save` is now awaitable, but no test awaits it; the brief exempted the job from tests-first, so confirm that is acceptable.
- night_flow_provider_test.dart:42: the fake was copied, not shared; the brief allowed the copy.

## Could not check

- Tests and `dart analyze` were not run: this review changes nothing, and `tools/mine.sh` reformats files. So the "fails on the old code" claim for the two new provider tests, and the "no analyzer findings" claims, are unverified.
- Whether the scoreboard screen stalls after the last round: night_scoreboard_screen.dart:69 and :149 and game_screen.dart:268 read the provider; I did not trace the UI path.
- That `pumpEventQueue` is available from `flutter_test` as imported: relies on the worker's analyzer run.
- Line widths: a grep for lines over 120 columns in the five changed files found none.

## Commit message — a draft

Subject: `docs: review of night1c wave-3 jobs f1 and f2`

Body:
- Adds the wave-3 review report for f1 (night controller ends with the night)
  and f2 (awaitable NightSettingsStore.save, badge ring test as a plain test).
- Finds one must: the provider drops the controller on the last round, so
  NightCeremony and NightEnded never fire.
- Records two shoulds and coulds: a real Timer left in a provider test,
  a third copy of the fake scheduler, and pumpEventQueue timing waits.
- No code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

night1c wave-3 review done (f1, f2 reviewed; verdict needs Claude): open is the must that the provider's last-round dispose skips the ceremony and NightEnded, plus the real Timer in the provider test; tests and analyze not run.

## Delete

- none
