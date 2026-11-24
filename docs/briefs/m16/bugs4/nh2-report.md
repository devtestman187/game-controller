# M16 bugs4 nh2 — the night's end is sent when the awards reveal ends

STATUS: stopped. The code and the new tests are done and pass. The job's check cannot pass as briefed: two existing test files outside `allow:` now fail, and they need a host override that I am not allowed to add (see Blocked).

## Summary

What changed (lib):
- `packages/party_host/lib/src/night/night_end.dart` (new): `nightEndFor(night, players)` builds the `NightEndMessage` from `night.outcomes` (one `NightAwardRow` per award: id = award name, name = title, points = `awardPoints`, winners, reason) and `viewStandingsOf(night.rows(players))`.
- `packages/party_host/lib/src/night/round_results.dart`: the standings are built from `recorded` (no `withAwards`), so a last-round card never names or counts the awards. The ViewStanding list moved into the public `viewStandingsOf(rows)`, which `viewResultsFor` also uses. `round`, `of` and `place` now come from `recorded` too, so they agree with the standings. `NightState.withAwards` is kept (PartyNight uses it).
- `packages/party_host/lib/src/ui/night_reveal_screen.dart` `_finish`: when the night is over, sends `nightEndFor(...)` once, before the `pushReplacement`. The existing `_finished` flag guards it, so Escape, Back and the timer path all send exactly once.

Tests:
- `packages/party_host/test/night_end_send_test.dart` (new, 5 tests, written first and seen failing): nothing sent while the reveal runs; Escape sends exactly one; the timer path sends exactly one; the awards' ids, names, points, winners and reasons in order; the standings' ids, points, order and numbers equal `night.rows(players)`; and a case where the awards change first place.
- `packages/party_host/test/round_results_test.dart`: the B-040 awards test now expects the last round's standings to be the totals before the awards. The guard test is unchanged.

Test setup note: the sample state has p2 still pairing, so the test helper sets p1 and p2 both connected (`fake.state` plus `fake.emit()` and a pump). Without the pump the night starts before p2 is known and Best Helper has no eligible winner.

Computed test values:
- Rounds: R1 p1 3 / p2 4 (p2 carries 1); R2 p1 3 / p2 2; R3 p1 3 / p2 1. Totals before awards: p1 9, p2 7.
- Awards `[bestHelper, comeback, catCatcher]`: Best Helper → p2, reason "Most carries home together: 1". Comeback → p1, "Most points in the last round: 3". Cat Catcher → nobody (winners `[]`, reason null).
- Final standings in the message: p1 12 (9 + 3), p2 10 (7 + 3); the host's `rows` gives the same.
- Timer: won 4000 ms + won 4000 ms + missed 2000 ms = 10 000 ms. At 8 000 ms nothing is sent; the message is sent at 10 000 ms.
- Awards `[bestHelper, catCatcher, tryAgain]`: p2 10, p1 9, so the message's first standing is p2 (the round card's first is p1 9).
- round_results last-round card: Mia 9, Ben 7 (was 10 / 9 with the awards). Host's final rows: Ben 10, Mia 9.

Checks run:
- `tools/mine.sh` (format, analyze, touched tests, churn revert): `OK 10 tests packages/party_host`, `RESULT: ok`. Run after each fix; the first run was the expected failure before the lib change.
- `flutter test` on `night_reveal_test.dart`, `night_round_test.dart`, `round_results_test.dart`, `night_end_send_test.dart`: all pass (+31).
- `flutter test` on `night_reveal_frame_test.dart`: FAILS (see Blocked).
- `flutter test` on `night_reveal_tie_test.dart`: FAILS (see Blocked).
- `tools/check.sh` was not run by me (the runner does it).

Self-check (review-rules part A):
1. Host setups: the TV/PC host is the one sending (`night_end_send_test`). No phone code changed; the phone-side setups are untouched.
2. Kept state: nothing is kept. `nightEndFor` is pure. It is sent once per reveal by `_finished` (`night_end_send_test`: "nothing is sent while the reveal runs" and "exactly once").
3. Combinations: the reveal ends by Escape, by Back (`_finish` via PopScope) or by the timer, all through `_finish`, so all three send. Early-ended nights do not open the reveal (`night.isOver` guard). Pause, away players and dropped links are not touched by this change.
4. Stayed in the job's folder and `allow:`: yes, except the two blocked test files I did not touch.
5. Stopped rather than overstepped: see Blocked.
6. Looks: no widget or layout change; no look-sized widget was added.

## Blocked

`night_reveal_frame_test.dart` (not in allow) and `night_reveal_tie_test.dart` (not in allow) fail now:
- The frame test's `ProviderScope` does not override `hostServiceProvider`, and its Back case reaches `_finish`, which now reads `gameHostProvider`. The real `LiveHostService` is then built in the test.
- The tie test fails with `UnimplementedError: hostIdentityProvider must be overridden` for the same reason.

Fix needed (outside this job's allow list): in those two files add `hostServiceProvider.overrideWithValue(...)` (for example a `FakeHostService` from `package:party_host/testing.dart`), or do it in a shared test support file. I did not edit them.

Other test files that finish a reveal without a host override may fail the same way. I did not run them (not in the brief); the runner's full suite will show it.

## Decisions

- Robo's standing keeps `id` null. The brief says "set `id: row.id`", but the `ViewStanding.id` doc in protocol says null for Robo. I followed the protocol doc.
- `NightAwardRow.points` is `awardPoints` for every award, including one nobody won (the brief's literal wording). The +3 is not given to nobody, but the row still says 3. The phone would show "+3" on a "Not won" row if it used this field. Please confirm.
- `place` in a last-round card now comes from the pre-award rows, to match the standings it sits beside.

## Questions

1. Approve adding a `hostServiceProvider` override to `night_reveal_frame_test.dart` and `night_reveal_tie_test.dart` (or a support helper), so the job can pass? This is the only blocker.
2. Robo's `id` is null in `viewStandingsOf` (protocol doc) — OK, or should Robo carry `roboPlayerId` as the brief reads?
3. Should an unwon award's `points` in `NightAwardRow` be 0 instead of 3?
4. `tools/mine.sh` printed "churn: reverted 3 generated file(s)" (tv_test_app/windows/flutter/generated_*). Those files were already modified in the working tree when I started. Please check they were not my doing and that the revert did not undo your pending changes to them.

## Commit message — a draft

M16 bugs4 nh2: the host sends the night's end when the reveal ends

The reveal's end (timer, Escape or Back) now sends the phones a night_end
message once: the night's three awards in reveal order and the final
standings with their award points, built by nightEndFor from the night's
outcomes and rows. The last round's standings come from the recorded
night with no awards, so the last-round card does not name or count them.
viewStandingsOf is shared by the card and the night's end.
Tests: night_end_send_test (new) and the B-040 awards test in
round_results_test. Two existing reveal test files still need a
hostServiceProvider override (not yet done).

## Status row

nh2 (bugs4): done — host sends night_end once when the reveal ends or is skipped; last-round card has no awards; new night_end_send_test passes. Open: night_reveal_frame_test.dart and night_reveal_tie_test.dart need a hostServiceProvider override (outside allow:).

## Delete

- none
