# M14 bugs11 b021-end-night-1: "End night" on the Bumper Round's night results (B-021, phase 1 of 2)

Status: **done**. The Bumper Round's results card ends the night on the round just played; the Shape Race card is phase 2.

## Summary

- **Core:** `PartyNight.endNow(RoundResult)` records the round just played, ends the night before its last round and decides the three awards exactly as the last round's path does, so `isOver` is true and the reveal, then the final scores, follow. The night keeps every round played, its points, its counters and its awards.
- **State:** `NightState` gains `isEndedEarly` (a field) and `endedEarly()`, which sets it; `isOver` is now `isEndedEarly || round >= rounds`; `roundsLeft` is 0 once the night is over, however it ended.
- **Card:** in a night, `ArenaResults` shows "End night" (key `endNight`, `NightText.endNightNow`) beside Next, unless the round on the card is the night's last. It calls the new `onEndNight`.
- **Screen:** `game_screen.dart`'s `_endNight` calls `endNow`, then pushes `NightRevealScreen` over `isGamePickerRoute` — the same route handling as `_next`, now shared as `_showAfterNight`.
- **Layout finding:** the night's two buttons are a `Row`, not the old shared `Wrap`: ToyCard's `IntrinsicWidth` takes the wrap's max intrinsic width, which sums children but not their spacing, so Next and End night broke onto two lines and D-pad Right never reached End night (measured: card 284 px, Next at x 289, End night at x 289, y one line down). With the Row the card is 394 px inside and Right walks to End night.
- **Last round:** only Next shows, since it already ends the night; `game_screen.dart` passes `lastRound: night.isNextRoundTheLast`.
- **File sizes:** all touched lib files stay under 380 lines (arena_results 351, game_screen 374); `_debugKeys` moved into `game_debug_overlay.dart` as `debugKeys`, since the wiring would have pushed `game_screen.dart` past 380.
- **Tests:** the new `end_night_arena_test.dart` (4 cases) failed on the old code (3 failures); `arena_results_test`'s night case now expects End night too, plus a new last-round case; `menu_press_test` pins the A/Right walk on a night card.
- **Docs:** design section 4 has the "Ending early" bullet, quoting the owner.
- **Checks:** format, analyze, host (472 tests) and phone (475 tests) all PASS.

## Files changed

- `packages/party_host/lib/src/night/night_state.dart` — `isEndedEarly` field (constructor, `_copyWith`), `endedEarly()`, `isOver`, `roundsLeft`; +14 lines, 330 total.
- `packages/party_host/lib/src/night/party_night.dart` — `endNow(RoundResult)`: remember + record + `endedEarly()` + `_decide`/`awarded`, guarded on a null or over night; 131 lines.
- `packages/party_host/lib/src/text/night_text.dart` — `endNightNow = 'End night'` (the dialog's question stays `endNight`).
- `packages/party_host/lib/src/ui/arena_results.dart` — `lastRound` and `onEndNight`; the night's Next/End night in a `Row`, the old three-button `Wrap` unchanged outside a night; 351 lines.
- `packages/party_host/lib/src/ui/game_screen.dart` — `_endNight`, `_showAfterNight` (shared by `_next`), `lastRound`/`onEndNight` wiring, `debugKeys` import; 374 lines.
- `packages/party_host/lib/src/ui/game_debug_overlay.dart` — `debugKeys`, moved from `game_screen.dart` (a `final` set: `LogicalKeyboardKey` has no const equality); 140 lines.
- `packages/party_host/test/end_night_arena_test.dart` — new: 4 cases (button shows beside Next; End night → reveal → final scores with the round's points in the standings; last round has no button; a phone host's card).
- `packages/party_host/test/arena_results_test.dart` — helper passes `lastRound`/`onEndNight`; the night case renamed to "Next and End night, and each records the round" and expects both; new "last round has Next alone" case; the non-night case checks End night is absent.
- `packages/party_host/test/menu_press_test.dart` — both `ArenaResults` calls pass the new parameters; new case: A on Next twice, D-pad Right, A on End night twice.
- `docs/design/party-night.md` — section 4's "Ending early" bullet (B-021).

## Computed test values

- `end_night_arena_test`, "End night ends the night on the round just played": a 3-round night with one round already recorded for 5 points (`roundResult(points: {'p1': 5}, winners: {'p1'})`), then the second round played out (60 s clock) against Robo (one player, design §7a).
  - The round on the card is read from `ArenaResults.result.points['p1']`: 0 in my runs — Robo took the coins and its +5, so P1 scored nothing. The test reads the value instead of pinning it, since the round is random.
  - After End night: `night.round` 2 (the recorded round plus the played one), `isOver` true (2 of 3 rounds, ended early), `totals['p1']` = 5 + points = 5, `outcomes` length 3 (all decided, as a last round's are).
  - Reveal → final scores: pumped `3 × nightAwardRevealMs` (3 × 4000 ms) then settled; "Final scores" and `NightScoreboardScreen` found.
  - Standings total checked as `5 + points + awardPoints × awardsWonBy('p1')` = 5 + 0 + 3 × 0 = 5: P1 won no award (Comeback needs at least 1 point in the last round, Sharpshooter at least 3 snaps, Best Helper at least 1 carry; the Arena reports none of these for this round).
- `end_night_arena_test`, last-round case: 2 of 3 rounds recorded, so `isNextRoundTheLast` is true; `next` present, `endNight` absent.
- `menu_press_test`: presses A, A, Right, A, A on a night card → `['next', 'next', 'endNight', 'endNight']`, so Next keeps the first focus and Right reaches End night.
- `arena_results_test` last-round case: `night: true, lastRound: true` → `next` present, `endNight` absent.

## Self-check (review-rules part A)

1. **Every host setup:** the card is the same widget on a TV/PC and a phone host; the new test pins a phone host (`fake.shareView = true`). A joined phone never draws this card (design §9: its own result came with the frame), and nothing new goes over the wire, so an older phone or host is unaffected.
2. **When kept state starts and ends:** `isEndedEarly` starts false in `NightState.start`, is set once by `endedEarly()`/`endNow`, and ends with the night (`PartyNight.end()` clears the state; the final scores' "Back to games" also clears it). A night that is already over ignores `endNow` (`isOver` guard), so nothing is recorded twice.
3. **How a new state combines with the others:** only the results stage changes; the pause menu and the away cards belong to the running round (`Pausable`), which is over by then. The results card still owns its stage alone (review-rules A3), and Back on it still records like Next (`_leave` → `_next`), unchanged.
4. **Stay in the job's folder:** only files in `allow:` were changed, all under `packages/party_host/` plus the two docs (design doc and this report).
5. **Stop rather than overstep:** nothing needed a file outside `allow:`; the layout fix stayed inside `arena_results.dart`.

## Hand-over (exact core API for phase 2)

```dart
// NightState (packages/party_host/lib/src/night/night_state.dart)
final bool isEndedEarly;              // true once the host ended the night early
NightState endedEarly();              // the night with isEndedEarly set
bool get isOver;                      // isEndedEarly || round >= rounds
int get roundsLeft;                   // isOver ? 0 : rounds - round

// PartyNight (packages/party_host/lib/src/night/party_night.dart)
void recordRound(RoundResult result);  // Next: record; awarded only when the record ends the night
void endNow(RoundResult result);       // End night: remember + record + endedEarly + awarded (no-op if null/over)
```

The Shape Race card's wiring is the same three pieces: a `lastRound` flag fed by `night.isNextRoundTheLast`, an `onEndNight` on the card, and `puzzle_screen.dart`'s equivalent of `game_screen.dart`'s `_endNight`:

```dart
void _endNight() {
  final result = _result;               // the round's RoundResult
  if (result == null) return;
  ref.read(partyNightProvider.notifier).endNow(result);
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const NightRevealScreen()),
    isGamePickerRoute,
  );
}
```

`NightText.endNightNow` ('End night') and the key `endNight` are shared, so phase 2 needs no new text.

## Questions and suggestions (not acted on)

1. **Two-button cards and `IntrinsicWidth`.** A `Wrap`'s max intrinsic width sums its children without their `spacing`, so ToyCard (which wraps its child in `IntrinsicWidth`) breaks two buttons onto two lines whenever the card has nothing wider. `NightGameButtons` in `night_widgets.dart` relies on the scoreboard being wide for the same reason. Suggest a shared two-button row widget (or fixing the wrap's spacing) so every card gets the same walk; I used a local `Row` here.
2. **The phone's card after End night.** Joined phones keep their last `view_result` and "Waiting for the host to pick what's next"; the night's ending is not sent to them. Out of scope here (b3/c3); say if it should be.
3. **`roundsLeft` change.** It now reads 0 once a night is over early, not `rounds - round`. Nothing in `lib/` reads it after the night ends; revert if the raw count is wanted.

## Checks

`tools/check.sh format analyze host phone` → PASS format, PASS analyze, PASS host (472 tests), PASS phone (475 tests).

Tests run on their own: `end_night_arena_test.dart` (4), `arena_results_test.dart` (8), `menu_press_test.dart` (3), `arena_night_test.dart` (7), `night_reveal_test.dart` (5), `night_round_test.dart` (15) — all passed after the change; the new file failed on the old code as required (3 of its 4 cases: the button missing, and End night not ending the night).

## Commit message

Add End night to the Bumper Round's night results (B-021)

The night's round results card has "End night" beside Next, before the
night's last round, so a host can stop after any round. It records the
round just played and ends the night on it, keeping every round, its
points and its awards, and the awards' reveal and then the final scores
follow, as after the last round. Next keeps the first focus and the
remote's Right reaches End night. The night's last round keeps Next
alone, since Next already ends the night.

## Status row

B-021 phase 1 done: End night on the Bumper Round's night results (core `PartyNight.endNow`/`NightState.endedEarly`, the card's End night, the reveal then final scores; tests + design §4). Open: B-021 phase 2, the same on Shape Race's results card.

## Delete

- none
