# d2h report: the how-to card carries the director's reason

## Summary

- `NightHowTo` takes an optional `reason` (a `DirectorReason`). Its facts add `'reason'` only when it is set, so every existing event and test is unchanged.
- `NightFlowController` (both constructors) takes `reasonFor`, asked as each how-to card is emitted. The resumed replay builds its cards without asking.
- The provider passes `reasonFor` as `pickFor(round)?.reason`; a host-picked night gets null.
- `captionFor` reads `How to play round $r: <phrase>` with a reason, the old text without one. The phrase switch covers every `DirectorReason`, no default.
- New tests in `test/night_how_to_reason_test.dart`: facts, equality, five captions plus the no-reason caption, controller with and without `reasonFor`, resumed replay, provider.
- `tools/mine.sh`: format OK, analyze OK after one fix (unused import removed), 102 tests OK in party_host.

Decisions:
- The resumed constructor now has six named parameters (rules say at most five). The brief asked for `reasonFor` on both constructors, so I followed it. See question 1.
- The new tests live in a new file, as the rules require. The brief's allow list also names `night_captions_test.dart` and `night_flow_controller_test.dart`, but I left both unchanged.
- The controller tests use a small held-timer clock copied into the new file, because the fake clock in `night_flow_controller_test.dart` is private to that file.

## Files changed

- `packages/party_host/lib/src/night/night_flow.dart`: `NightHowTo(this.round, {this.reason})`; facts gain `'reason'` only when set; imports `night_director.dart`.
- `packages/party_host/lib/src/night/night_flow_controller.dart`: imports `night_director.dart`; `reasonFor` field and constructor parameter on both constructors; `_emitHowTo` passes `reasonFor?.call(round)`. The replay still emits `NightHowTo(round)` with no reason.
- `packages/party_host/lib/src/night/night_flow_provider.dart`: builds `reasonFor` from `nightPickProvider.notifier.pickFor(round)?.reason`; imports `night_director.dart` and `night_pick_provider.dart`.
- `packages/party_host/lib/src/night/night_captions.dart`: how-to caption with the reason phrase; `_howToPhrase` switch over `DirectorReason`, no default.
- `packages/party_host/test/night_how_to_reason_test.dart` (new): 14 tests, all in the file. The tests-first step is exempt (new field, cannot compile on base).
- `docs/briefs/m17/night2b/d2h-report.md` (new): this report.

## Checks

- `tools/mine.sh`: format OK (5 files formatted), analyze OK for `packages/party_host` after one fix (unused `flutter_riverpod` import removed), touched tests OK: 102 tests in party_host.
- I did not run `tools/check.sh` or `flutter test` on the new file alone; the 102 count covers it, but I did not read per-test output.

## Self-check (review-rules part A)

1. Host setups: the change is in the night controller and captions only, so no host screen changes. A picker-host night gets `reasonFor` returning null, so its cards are unchanged (covered by the no-`reasonFor` controller test).
2. Kept state: no new state; `reasonFor` is a stored callback like `onEvent`, dropped with the controller on dispose.
3. Combinations: the resumed replay never asks (controller test "a resumed night replays..."). Pause, host away and the others do not touch `_emitHowTo`'s reason path.
4. Files: all inside the allow list, plus the report.
5. Nothing stopped.
6. Looks: no UI change.

## Hand-over

- The provider test asserts the how-to reason equals the director pick for round 2. It does not assert which reason the seeded director gives (pool and totals are 0-0). I did not compute that value.

## Commit message — a draft

Night how-to card carries the director's reason

NightHowTo takes an optional DirectorReason; its facts carry it only
when set, so existing events and tests are unchanged. The controller
asks reasonFor as each how-to card is emitted, not for replayed rounds
of a resumed night. The provider passes the director's pick reason
(null for a host pick). captionFor reads "How to play round N: <phrase>"
with a reason, so a hidden change is announced in plain words.
Thumby will show it later; no UI or protocol change.

## Status row

d2h done: how-to card carries the director's reason (event, controller, provider, caption; tests pass). Open: the resumed constructor now has 6 params (rule is 5); no screen shows the caption yet.

## Delete

- none

## Questions

1. The resumed constructor has six named parameters (rule: at most five). Do you want a value object for the callbacks (`pacing`, `schedule`, `onEvent`, `reasonFor`), or is the brief's both-constructors wording the final word?
2. Should the captions test move to `night_captions_test.dart`, as the allow list suggests, rather than the new file? I kept the new file to follow the new-tests rule.
