# M16 bugs4 np1 — report

## Summary

The joined phone now keeps the night's end, and the last round's card says "Awards coming…" in place of the standings and the winner line. No host or protocol change. The awards and the final winner stay for np2.

Changes:

- `controller_app/lib/src/providers/night_end.dart` (new): `nightEndProvider`, a `NotifierProvider<NightEndNotifier, NightEndMessage?>`. It holds the client's `nightEnds` message. It is cleared by a `ViewStarted` and when the link drops (`clientStateProvider` not connected), the same clearing rules as `viewResultProvider`.
- `controller_app/lib/src/providers.dart`: exports `providers/night_end.dart`.
- `packages/party_host/lib/src/text/phone_text.dart`: `static const awardsComing = 'Awards coming…';` (real ellipsis, as "Searching…" and "Connecting…" write it). `youWonNight` and `nightWinner` are kept, unused in lib, for np2.
- `controller_app/lib/src/ui/result_night.dart` (new): `ResultNight` (the points line, then on the last round the awards line, otherwise the standings heading and rows), `ResultBadge` (was `_Badge`), and the private `_StandingRow`, moved from `result_card.dart`. `ResultNight` replaces the old `_night` helper, which returned a list of widgets; a widget is used instead (G3: no widget-returning helpers). The layout is the same: a `Column` with `min` size and `stretch` alignment inside the card's `Column`.
- `controller_app/lib/src/ui/result_card.dart`: 297 → 190 lines. `_night`, `_nightWinnerLine`, `_Badge`, `_StandingRow` removed; uses `ResultNight` and `ResultBadge`. The `resultNightWinner` line is gone from the card.
- `controller_app/test/night_end_provider_test.dart` (new): four tests, see the test values below.
- `controller_app/test/result_card_night_test.dart`: the B-040 winner-line group is replaced by "the last round's card says the awards are coming (np1)".
- `controller_app/test/coverage_all_test.dart`: imports `providers/night_end.dart`, like the other provider files.
- `packages/party_host/test/phone_text_test.dart`: one test for `PhoneText.awardsComing`.

Tests seen this job:

- `tools/mine.sh` (last run after the final edit): `OK 4 tests packages/party_host`, `OK tests controller_app` (the touched test files), `RESULT: ok: 9 file(s) formatted, 2 package(s) analyzed, 2 package(s) tested`.
- `flutter test test/m14_phone_test.dart test/result_card_fit_test.dart` in controller_app (run directly, because mine.sh runs only the touched test files): `All tests passed!` (8 tests: 7 in m14_phone_test.dart and 1 in result_card_fit_test.dart).
- Before the lib change, the new tests were run through mine.sh and failed to compile: `Undefined name 'nightEndProvider'` in night_end_provider_test.dart and `Member not found: 'awardsComing'` in result_card_night_test.dart. That is the "fail on the code as it was" evidence for this job.

## Test values

Provider (`night_end_provider_test.dart`):

- Before any night end: `nightEndProvider` is null.
- After `client.nightEnd(end)` and one flush: `same(end)`.
- After that, `client.viewStart(arenaStart())`: null.
- Link up (`connected`), night end held; then `ClientSnapshot(status: idle)`: null.

Card (`result_card_night_test.dart`):

- Round 3 of 3, players 1 and 2, standings Mia 12 and Dad 9: `Key('resultAwardsComing')` shows `'Awards coming…'`; no `resultNightWinner`; no `standing-1`/`standing-2`; `resultWaiting` present.
- Round 3 of 3 tie (Mia 12, Dad 12, Sam 7), player 3: awards line; no winner line; no `standing-3`.
- Round 2 of 3: `standing-1` and `standing-2` present; no awards line; card present.
- Round null (no night): standings present; no awards line.
- Sizes 568x320 landscape, sunny and night palettes, six standings at round 3 of 3: awards line present; waiting line top >= 0 and bottom <= 320; no exception.

## Decisions

- `_night` became a widget (`ResultNight`), not a function returning a list, to follow G3.
- The awards line shows on the last round even when the round has no standings (the brief said to replace the standings and the winner line, and the awards line should not depend on standings).
- The awards line uses the standings heading's style (`body`, `inkSoft`), not centred, as the brief said.
- The points line stays on the last round (it is the phone's own points, not standings).
- `_Badge` moved as the brief says, but it is used by `result_card.dart`'s name row, so it is public as `ResultBadge` in `result_night.dart`.
- The phone_text test is in the existing `phone_text_test.dart` (the brief allows it), not a new file as G9 prefers.

## Self-check (review-rules part A)

1. Host setups: no host change; the card is the phone's own (player tests in result_card_night_test via `endRound` for players 1 and 2 and the m14 results-card tests).
2. Kept state: `nightEndProvider` starts null and is cleared by a new view and a dropped link (night_end_provider_test, four tests).
3. Combinations: the awards line is shown on the last round only; the pause menu, host away, player away and "Get ready" are not changed by this job (the card is not touched by them). Leaving: the provider is cleared on a dropped link, and nothing else is changed.
4. Stayed inside allow: yes. The generated plugin files that `tools/mine.sh` churns were reverted by the script; `git status` shows only the allowed files plus the pre-existing docs changes that were there at the start.
5. Stops: none.
6. Looks: the card is tested in the sunny and night palettes at 568x320 (fit test and the night card test). The awards line has no fixed height.

## Questions

1. `result_night.dart` has two public types, `ResultNight` and `ResultBadge`. Suggestion: move the name row's badge to a plain `ToyBadge` call and delete `ResultBadge`, which keeps one public type per file. I kept it as the brief asks.
2. `PhoneText.youWonNight` and `PhoneText.nightWinner` have no lib use now; np2 uses them. The test in `phone_text_test.dart` still covers them.
3. The brief's step 4 asks for m14_phone_test and result_card_fit_test. mine.sh does not run untouched test files, so I ran them directly with `flutter test` in controller_app. Please say if that counts as a second run of a suite the rules did not allow.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
M16 bugs4 np1: the phone keeps the night's end; last round says awards coming

The joined phone keeps the night's end in nightEndProvider, cleared by a
new view and by a dropped link, as viewResultProvider is. On a night's
last round the result card shows "Awards coming…" in place of the
standings and the winner line (B-040): the awards are shown after the
host's reveal, in np2. _night becomes the ResultNight widget, and
_Badge and _StandingRow move to result_night.dart so result_card.dart
stays under 300 lines.
```

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

np1 done: the joined phone keeps the night's end (nightEndProvider), and the last round's card says "Awards coming…" with no standings or winner line. Open: np2 (awards and final winner after the host reveal).

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`. You can't delete files: the script deletes these after you finish.

- none
