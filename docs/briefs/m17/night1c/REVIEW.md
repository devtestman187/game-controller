## Summary

Verdict: **one fix batch** (Claude decides the phone ring, finding 5, and the public-type split, finding 7).
Counts: must 1 · should 7 · could 2. Verdicted wave findings (REVIEW-VERDICTS.md) and the items f1, f2, f3 fixed are not repeated.
The five that matter most:
1. **must** The provider drops the controller on the last round, so NightCeremony and NightEnded never fire (night_flow_provider.dart:19). Nothing consumes the events yet, so no player sees it today; f1's test at night_flow_provider_test.dart:110 pins the bug.
2. **should** The host ring also draws on the phone: PlayerBadge is used by the phone app (bar_connection.dart:270, lobby_players.dart:41), against e0d's "host badges only".
3. **should** The bumper branch at night_scoreboard_screen.dart:86 is dead while `nightBumperRoundReady` is `const true`.
4. **should** New tests were added to existing files (puzzle_pick_test.dart:128, night_controls_test.dart:263); the rule is new tests in a new file.
5. **should** docs/code-health.md:344 says championsAmong has no lib caller; n1j wired it (night_scoreboard_widgets.dart:99).

Owner questions (details under Open questions): skip and reroll give no points and burn no round (DRIVER-NOTES 1); chaos default `off` or `little`; the controller never starts a round by itself until nightNextVariantProvider has a value (night_variant.dart:8, B7).
Checks: none run (read-only job). Read: the diff stat, the 9 job reports, the 4 wave reviews, the verdicts, run.log, and the lib files named in the findings (the controller and the settings file in full).

## Findings

- **must** packages/party_host/lib/src/night/night_flow_provider.dart:19 the select returns null once `night.isOver`, and `isOver` is `round >= rounds`, so recording the last round disposes the controller and cancels the ceremony step `_armScoreboard` arms (night_flow_controller.dart:308-309; dispose clears it at :240) → keep the controller until its flow reaches `ended` or the night ends early, and change the test at night_flow_provider_test.dart:110 to expect `next()` to apply NightCeremony and NightEnded (from: wave3 review, f1)
- **should** packages/party_host/test/night_flow_provider_test.dart:130 the test "ending the night disposes the controller" arms a real `Timer(after, fire)` in its scheduler override, against the no-real-time rule → use the `_FakeScheduler` at :42 and assert `clock.waiting` (from: wave3 review, f1)
- **should** packages/party_host/test/night_settings_test.dart:109 (also :121, :131) `await pumpEventQueue()` waits on queue timing instead of the write, the same kind of delay f2 was meant to remove → await `container.read(prefsProvider).reload()` and read the saved value (the brief's first option) (from: wave3 review, f2)
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:86 `!nightBumperRoundReady` can never be true (party_night.dart:21 is `const true`), so the branch is dead code and its dartdoc words at :80-81 describe it → remove the branch and reword the dartdoc, or keep it only as an owner decision (from: wave4 review, f3)
- **should** packages/party_host/lib/src/ui/player_badge.dart:60-69 the ring is drawn for players 7 and 8 wherever PlayerBadge is shown, and the phone app shows it (controller_app/lib/src/ui/bar_connection.dart:270, lobby_players.dart:41, host_chip.dart:47); e0d's stop was "host badges only, no change to the phone app", and its self-check "phone setups unaffected" is wrong → draw the ring only inside the host frame (`HostFrameInfo.maybeOf`) or get the owner's OK; the phone tests host_chip_test.dart:73, identity_phone_test.dart:54 and lobby_alignment_test.dart:45 pin PlayerBadge (from: e0d)
- **should** packages/party_host/test/puzzle_pick_test.dart:128 and packages/party_host/test/night_controls_test.dart:263 f3 added its tests to existing files, but the guideline says new tests go in a NEW file → move both new tests into a new file under test/ (from: f3, wave4 review; across jobs)
- **should** packages/party_host/lib/src/night/night_flow_controller.dart:9 and :77 the file declares five public types (NightSchedule, NightRoundHooks, NightPausable, NightPacing, NightFlowController), and packages/party_host/lib/src/night/night_settings.dart:26, :180, :218 declares three more besides NightPicker; coding-guidelines.md:45 says one public type per file → split the store, the notifier and NightPacing/NightRoundHooks/NightPausable into their own files; the briefs named these in one file, so this is Claude's call (from: across jobs)
- **should** docs/code-health.md:344 "championsAmong has no lib caller" is false since n1j (night_scoreboard_widgets.dart:99 calls it) → delete that clause (from: across jobs)
- **could** packages/party_host/lib/src/ui/puzzle_pick.dart:227 the three lines `ref.read(nightFlowControllerProvider)`, `roundEnded()`, `next()` repeat game_screen.dart:269 → one helper that both screens call (from: wave4 review, f3)
- **could** packages/party_host/lib/src/ui/puzzle_screen.dart:379 and packages/party_host/lib/src/ui/game_screen.dart:366 both sit near the 380-line limit (379 and 366), and f3 and n1i each added to them → the next job that touches either splits it first (from: wave4 review, n1i)

## Open questions

1. Skip and reroll replace the game, never use a round, and give nobody points? Suggested: keep as built; the points rule waits for replaceRound (DRIVER-NOTES 1).
2. Chaos default: `Chaos.off` (brief's literal) or the host's saved `little`? Suggested: keep `off` until the owner decides (n1h Q1).
3. Auto-start needs `nightNextVariantProvider` (night_variant.dart:8, always null); until B7 the night waits at the how-to card for a host press? Suggested: yes, leave it; confirm B7 owns the provider.
4. After `startRound` returns false, the controller does not re-arm, so the night waits for a host press with no timer (night_flow_controller.dart:267-268)? Suggested: keep it; the host press is the way on.
5. New tests in a new file, or the brief-named files (f3 Q1)? Suggested: the rule: new file (finding 6).
6. The bumper guard: variant-specific, or the flag only? Suggested: variant-specific, and delete the dead branch (finding 4).
7. A phone-host Shape Race Next test (f3 Q4)? Suggested: add it in a later job; not blocking.
8. `addPausable` during a pause does not pause the new pausable (n1g Q1)? Suggested: pause it at once when the night is paused, so no round runs on it unpaused.
9. Queued join and leave take the round they arrived in (n1g Q3)? Suggested: keep as built.
10. Start card's `startNow()` skips round 1's how-to wait (n1i decision)? Suggested: keep; the brief allows it.
11. Ring on the phone (finding 5): host frame only? Suggested: yes, the phone stays unchanged.
12. A direct `save` test (f2 Q1)? Suggested: add it in a later job; not blocking.
13. `min <= max` in the const constructor is checked only in copyWith and tryFromJson (n1h Q2)? Suggested: keep; a const constructor cannot compare levels.

## Numbers against targets

- Gap from a scoreboard to the next round's start: 8 s + 6 s = 14 s, target under 15 s (NightPacing.maxGap): meets.
- How-to card: 6 s, target 5 to 10 s: meets.
- Events of a night (n1f): 1 setup + 3 × 4 + 1 doubled + 1 ceremony + 1 ended = 16 for 3 rounds; 24 for 5 rounds: as computed.
- Host badge number (e0d): 0.55 × 37 = 20.35 px inside the frame, target at least 20 px: meets. Ring box 37 / 0.88 = 42.045 px, disc 37 px: as computed.
- Outside the frame: the number is 0.55 × 0.88 × size, so it reaches 20 px only when size is at least 41.3 px; the phone draws the ring at its own size (finding 5). Not met for small badges; the floor is not enforced there.
- Line counts against 380 (hard) and about 300 (soft): night_flow_controller.dart 326 (over 300; split in finding 6), night_settings.dart 230, night_scoreboard_screen.dart 180, puzzle_screen.dart 379, game_screen.dart 366: none over 380.
- Lines over 120 columns in the touched lib files: none found.

## Could not check

- No test, analyzer or dart format run (read-only); all counts come from the job reports and the run log.
- Tests-first proof: run.log has `tests-first ok` lines for n1h, n1f, e0d, n1g and n1i; n1j is exempt; f1 and f2 have no line in run.log (f1's report says it ran); f3 has none. All 9 jobs have a report.
- HAND-FIX: no `HAND-FIX` line in run.log.
- Fixed, unverified: needs device check. f3 items 1 and 2 (puzzle Next calls roundEnded/next; startRound route check) were fail-on-base reasoning only. n1i's round-hook tests fail on base only through a compile error, not a behaviour check. The TV and phone looks of the ring were not checked.
- Read only in part: night_state.dart apply rules (night_flow.dart :218-290), night_round_hook_test.dart, the night_scoreboard_widgets diff, the game_screen and puzzle_pick diffs (grep only), and most test bodies.
- controller_app tests that pin PlayerBadge were found by grep (3 files); none was run.
- Coding guidelines and review rules: the rules cited are from the grep of docs/coding-guidelines.md:41, :45, :92 and the worker extract; the rest of both documents was not read.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night1c run review: one must and seven shoulds for Claude

Read-only review of the whole night1c run (f1e0af2f..cfb48e92) against
the coding guidelines and review rules. Writes only REVIEW.md: 1 must,
7 should, 2 could; verdicted wave findings are left out. The must: the
provider drops the controller on the last round, so NightCeremony and
NightEnded never fire. The shoulds: a real Timer and pumpEventQueue waits
in tests, the host ring also drawn on the phone, a dead bumper branch,
tests in existing files, files with several public types, a stale line in
docs/code-health.md.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night1c run review: done, read-only, 1 must, 7 should, 2 could; open: the provider's last-round dispose (must) and the shoulds (real Timer, pumpEventQueue waits, ring on the phone, dead bumper branch, tests in existing files, public types per file, stale code-health line); Claude to decide the phone ring and the split.

## Delete

- none
