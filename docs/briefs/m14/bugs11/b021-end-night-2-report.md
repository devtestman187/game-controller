# M14 bugs11 b021-end-night-2: "End night" on Shape Race's night results (B-021, phase 2 of 2)

Status: **done**. A night's Shape Race results card ends the night on the round just played, as the Bumper Round's does.

## Summary

- **Card:** in a night, `_Results` (`puzzle_results_widgets.dart`) adds "End night" beside Next, with the same key (`endNight`) and text (`NightText.endNightNow`) as phase 1, unless the round on the card is the night's last. Both sit in one `Row` (as on the Arena card), not a `Wrap`, so ToyCard's `IntrinsicWidth` never breaks them onto two lines.
- **Screen:** `puzzle_screen.dart` passes `lastRound: ref.read(partyNightProvider)?.isNextRoundTheLast ?? false` and `onEndNight: _endNight`.
- **Wiring:** `_endNight` calls phase 1's `PartyNight.endNow(result.round)`, then pushes `NightRevealScreen` over `isGamePickerRoute` through a new `_showAfterNight`, copied from `game_screen.dart`. Back is unchanged (`_leaveForGames` still records the round through `_next`).
- **File size:** the results wiring moved to a sibling part file, `puzzle_screen_results.dart` (34 lines, an extension on `_PuzzleScreenState`): `_leaveForGames` moved verbatim, plus `_endNight` and `_showAfterNight`. `puzzle_screen.dart` is 371 lines (was 380); `puzzle_results_widgets.dart` 248.
- **Tests:** new `end_night_puzzle_test.dart` (4 cases) failed on the old code (3 of 4: the button missing, and End night not ending the night); all 4 pass now. No other test needed changing; the `read:` ones all still pass unmodified.
- **Docs:** the design's "Ending early" bullet now says both games' cards carry the button.
- **Checks:** format, analyze, host (476 tests) and phone (475 tests) all PASS.

## Files changed

- `packages/party_host/lib/src/ui/puzzle_screen_results.dart` — new part: `_PuzzleResultsRoute` extension with `_endNight`, `_showAfterNight` and `_leaveForGames` (moved verbatim from the screen); 34 lines.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — the new `part`, `_leaveForGames` moved out, `lastRound`/`onEndNight` passed to `_Results`; 380 → 371 lines.
- `packages/party_host/lib/src/ui/puzzle_results_widgets.dart` — `_Results` takes `lastRound` and `onEndNight`; `_buttons()` puts End night beside Next in a night before its last round; class doc updated; 248 lines.
- `packages/party_host/test/end_night_puzzle_test.dart` — new: 4 cases (button beside Next; End night → reveal → final scores with the round's points; last round has none; a phone host's card).
- `docs/design/party-night.md` — section 4's "Ending early" bullet: both games' cards, not one.

## Computed test values

- `end_night_puzzle_test`, helper: a 3-round night (`NightLength.three`, `threeAwards` = Best Helper, Comeback, Sharpshooter) with `roundsPlayed` rounds already recorded for 5 points each (`roundResult(points: {'p1': 5}, winners: {'p1'})`). The card's round is played by a solo P1 from the night's Shape Race pick and ended by `lockEveryPiece` + `endRound`, so every piece was put in by hand.
- The round on the card scored **5** (`PuzzlePoints.finish` 5 × `nightPointsScale` 1; no snaps, since placing by hand runs no snap awards). The test reads `match.result.round.points['p1']` rather than pinning it, as phase 1 did.
- "End night ends the night on the round just played" (1 round already played): after the press, `night.round` 2, `isOver` true (2 of 3 rounds, ended early), `totals['p1']` = 5 + 5 = **10**, `outcomes` length 3.
  - Final standings: `5 + 5 + awardPoints × awardsWonBy('p1')` = 10 + 3 × 1 = **13**. P1 wins Comeback alone (5 points in the last round, at least 1 needed); Best Helper needs a carry and Sharpshooter needs 3 snaps on top of the fewest wrong drops, and this round reports 0 of both, so both go unwon.
  - Reveal → final scores: pumped `3 × nightAwardRevealMs` (3 × 4000 ms) then settled; "Final scores" and `NightScoreboardScreen` found.
- Button case: `isNextRoundTheLast` false, `next` and `endNight` both present, `rematch`/`changeTeams` absent.
- Last-round case (2 rounds already recorded): `isNextRoundTheLast` true, `next` present, `endNight` absent.
- Phone host case: `fake.shareView = true` → `next` and `endNight` both present, no overflow.
- Old code: 3 of the 4 cases failed (`endNight` not found in the two button cases and in the End night press).

## Decisions

- **The button lives in `puzzle_results_widgets.dart`, not `_ResultButtons`.** `_ResultButtons` is in `puzzle_screen_widgets.dart`, which `allow:` doesn't list; the card wraps its night row with End night instead, as `arena_results.dart` holds its own night Row.
- **A `part` file, not a library.** `_leaveForGames`/`_endNight` read `_PuzzleScreenState`'s private fields, which only the same library may touch; `puzzle_pick.dart`/`puzzle_continue.dart` already split the state this way.
- **No new `_next` route.** `_next` stays in `puzzle_pick.dart` (not in `allow:`), so only the new `_endNight` uses `_showAfterNight`; the copy is exactly `game_screen.dart`'s.
- **Points read, not pinned.** The round's score depends on the puzzle's rules; the test reads it from the match, as phase 1's Arena test does.
- **Design doc: one clause.** The bullet already described the behaviour; it now names both cards instead of one.

## Self-check (review-rules part A)

1. **Every host setup:** the card is the same widget on a TV/PC and a phone host, and a new case pins the phone host (`fake.shareView = true`). A joined phone never draws this card (design §9), and nothing new goes over the wire.
2. **When kept state starts and ends:** no new state. `lastRound` is read from the night each build; `_endNight` uses phase 1's `endNow`, which ignores a null or already-over night, so nothing is recorded twice.
3. **How a new state combines with the others:** only the results stage changes; the card still owns it alone, and the pause menu and away cards belong to the running round, which is over.
4. **Stay in the job's folder:** only files in `allow:` changed (all under `packages/party_host/` plus the design doc and this report).
5. **Stop rather than overstep:** nothing needed a file outside `allow:`; the split stayed in the new sibling file.

## Questions and suggestions (not acted on)

1. **Focus walk not pinned for this card.** End night has no focus node of its own, so the remote's Right should walk from Next to it, as the Arena card's does (phase 1 pinned that in `menu_press_test`). The brief's four cases don't ask for it; a fifth case could pin it.
2. **Stale-looking widget doc.** `_ResultButtons`'s doc says "a night's round has the first button alone, Next (M14 c1)". Still true of that widget (the card adds End night around it), but it reads oddly now; `puzzle_screen_widgets.dart` is outside `allow:`.
3. **The shape race's last round test relies on the scoreboard route.** Recording rounds by hand before opening the round, as `night_round_test` does, is the only way to reach a last round without playing two whole rounds; if a future job makes the scoreboard pick differently, both tests change together.

## Checks

`tools/check.sh format analyze host phone` → PASS format, PASS analyze, PASS host (476 tests), PASS phone (475 tests).

On their own: `end_night_puzzle_test.dart` (4), `puzzle_results_test.dart` (11), `round_results_test.dart` (1), `night_screens_test.dart` (12), `menu_press_test.dart` (3), `night_round_test.dart` (16) — all passed.

## Commit message

Add End night to Shape Race's night results (B-021)

A night's Shape Race results card shows "End night" beside Next, before
the night's last round, so a host can stop after any round. It records
the round just played and ends the night on it, keeping every round, its
points and its awards, and the awards' reveal then the final scores
follow. The last round keeps Next alone, since Next ends the night. The
results wiring moves to a sibling part file so the screen stays under 380
lines; tests cover the button, the reveal, the last round and a phone
host.

## Status row

B-021 done: End night on both night results cards, the Bumper Round's (phase 1) and Shape Race's (phase 2), each ending the night on the round just played and the reveal then the final scores following; tests + design §4. Open: nothing on B-021; phase 1's open questions (two-button cards and `IntrinsicWidth`, the phone's card after End night, `roundsLeft`) stand.

## Delete

- none
