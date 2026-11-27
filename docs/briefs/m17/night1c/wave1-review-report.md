# Wave 1 review (n1h, n1f, e0d) — report

## Summary

small fixes: 0 must · 6 should · 3 could; the diff keeps the guidelines' size, naming and no-magic-number rules.
1. **should** `packages/party_host/lib/src/night/night_flow_provider.dart:16`: a night ended early by `endNow` keeps its controller, which auto-advances into rounds the host ended.
2. **should** `packages/party_host/lib/src/night/night_flow_provider.dart:21`: a saved night with every round played (not ended) gets a fresh controller that replays all rounds from setup.
3. **should** `packages/party_host/lib/src/night/night_settings.dart:36`: `NightSettings(difficultyMin: hard, difficultyMax: easy)` is constructible; only `copyWith` asserts and `tryFromJson` rejects it.
Nothing consumes the controller or the settings yet (no screen, no caller), so none of this reaches a player today.
Checks run: none (read-only job; `run-findings.md` does not exist; diff and files read by hand).

## Findings

- **should** `packages/party_host/lib/src/night/night_flow_provider.dart:16` `endNow` (`party_night.dart:94-97`) sets `isEndedEarly` without changing `length`, so the provider's `select` does not rebuild and the controller keeps auto-advancing after the host ended the night → watch `isOver` (or the ended-early flag) in the select, and dispose the controller then; decide with n1g, which adds the leave and skip paths.
- **should** `packages/party_host/lib/src/night/night_flow_provider.dart:21` `played < length.rounds` sends a night with `round == rounds` (all played, not ended, e.g. killed during the ceremony) to a fresh `NightFlowController`, so all rounds replay from setup → resume at the last scoreboard or the ceremony for `played == rounds` (the controller's `resumed` assert currently needs `< rounds`; relax it or add a stage parameter), and say so in the brief.
- **should** `packages/party_host/lib/src/night/night_settings.dart:36` the public const constructor accepts `difficultyMin` above `difficultyMax`; n1h's brief item 1 asked for the min-not-above-max assert, and it sits only in `copyWith` (line 87) → keep the reason in the report (see Decisions) and make the invalid case unreachable from the public constructor (private constructor plus a validating factory, or a `static` check the callers use).
- **should** `packages/party_host/test/night_flow_provider_test.dart:48` the resumed case uses the real scheduler (`nightScheduleProvider` is not overridden), so an 8 s real `Timer` is armed; guideline §9 says no real time in tests → add `nightScheduleProvider.overrideWithValue` with the fake from the controller test (as the test at line 60 does) and assert the armed pause.
- **should** `packages/party_host/test/night_settings_test.dart:30` `_settle()` waits with `Future<void>.delayed(Duration.zero)` for the unawaited prefs writes at `night_settings.dart:200` (`save`) and `:195` (`remove`); guidelines §2 (no delays to make a race go away) and §9 (await every async side effect) → make `NightSettingsStore.save` return its `Future<void>` and have the tests await it (the notifier's `update` keeps its own unawaited write, which is a decision).
- **should** `packages/party_host/test/player_badge_ring_test.dart:34` the badgeNeedsRing test is a `testWidgets` with no tester and no look, and the e0d report's self-check 6 says "all 4 tests run both via forEachLook", which is false for this test → make it `test(...)` and correct the report's self-check line.
- **could** `packages/party_host/test/night_flow_controller_test.dart:154` the how-to bounds test checks the constants against the constants (`howTo >= 5`, `<= 10`), which the `isPlayable` assert already enforces; the behaviour part (lines 158-164) is the real check → keep it, drop the two constant lines or keep them as a note.
- **could** `packages/party_host/test/night_flow_controller_test.dart:106` the controller file has 17 tests; `n1f-report.md` says 16 → correct the report's count.
- **could** `packages/party_host/lib/src/night/night_settings.dart:203` the decode catch and the removal of a broken save are silent (no `LogSink`), the same as `night_save.dart:38-41`; the house pattern, so fix it once for both stores, with a logged tag, in a later job.

## Decisions to confirm

- n1h `night_settings.dart:32` `Chaos.off` is the constructor default (PuzzleSettings, `packages/puzzle_game/lib/src/settings.dart:29`), while the host's saved default is `little` (worker question 1) → the owner picks; it is what the brief literally said.
- n1h `night_settings.dart:84-87` min-not-above-max is checked in `copyWith` and `tryFromJson` only, because a const constructor cannot read `Level.index` (worker's reason; I could not compile it here) → confirm the reason, or accept the finding above.
- n1h `night_settings.dart:39` `kids` leaves out `length` and `difficultyMin` (they equal the defaults) → harmless; the test pins all eight values (`night_settings_test.dart:68-79`).
- n1f `night_flow_controller.dart:95-96` `pacing` and `onEvent` are public final fields, because of `prefer_initializing_formals` → accepted by the worker; the controller's public surface is larger than the brief's list.
- n1f `night_flow_controller.dart:120-132` `startNow` at the last scoreboard does nothing and leaves the ceremony timer waiting (worker decision, tested at `night_flow_controller_test.dart:211`) → fine for n1g, which adds the leave.
- e0d `packages/party_host/lib/src/ui/player_badge_ring.dart:18` the ring's default key is one shared `Key('playerBadgeRing')` → fine today; the tests `find.byKey` would match every ring on screen, so a screen with two rings needs a key each.
- e0d `player_badge.dart:69` the ring box grows to 42.045 px only inside the frame; outside it the disc is 0.88 of `size`, so on a controller's pad a ringed badge can draw its number under 20 px (brief's choice; untested outside the frame).

## Could not check

- No check was run: the job is read-only, and I could not confirm the analyzer or the runner's counts (the workers' `tools/mine.sh` output is only in their reports).
- Whether `const` assert on `Level.index` is rejected by the analyzer (worker says it was): not compiled here.
- Whether `night_flow.dart` `NightFlow.apply` rejects every illegal event the controller sends: read only through the controller's tests, not the flow's code.
- Pixel results of the ring on a TV or a phone: only the widget tests exist; no device.
- Whether the players 1-6 tree is pinned by the existing `player_badge_test.dart` (not read).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night1c wave1-review: review report for n1h n1f e0d

Read-only review of the three wave-1 jobs against the guidelines,
review rules and their briefs. Writes only this report: 0 must, 6
should, 3 could. The should findings are for Claude to confirm: the
provider's replay after an early end and after the last round, the
settings constructor's min-above-max hole, and two timing waits in
tests.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave1 review (n1h, n1f, e0d): done, read-only, 0 must, 6 should, 3 could; open: fix the provider's early-end and replay-after-last-round cases, the settings min-above-max constructor, the real timer and the delayed settle in tests, and the badge test's look (Claude to confirm first).

## Delete

- none
