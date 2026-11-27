# n1j report: the final scores crown the night's champions through championsAmong

## Summary

- The scoreboard's crown and winner mark now come from `NightState.championsAmong(players)`, the one Quick night rule, instead of `row.place == 1`.
- Behaviour is unchanged on the base: `championsAmong` already equals place 1 (night_scoring_test pins it). The change is the wiring the code-health note asked for.
- No layout change, no new widget, no new rule. The crown, winner mark and medals look as today.
- Tests: 3 new widget tests in a new file. `tools/mine.sh` ran 44 tests across the touched files: OK.
- Tests-first: exempt. The behaviour is already right on the base; the new test pins the wiring and the tie case and may pass on the base.

## Files changed

- `packages/party_host/lib/src/ui/night_scoreboard_widgets.dart`: `_ScoreCard.build` computes `final champions = night.championsAmong(players)` once. The crown (`badgeMark`) is `over && champions.contains(row.id)`. `_data` takes a new `required bool champion` and sets `isWinner: over && champion`. The medal still uses `_medalOf(row.place)`.
- `packages/party_host/test/night_scoreboard_champions_test.dart` (new): three widget tests on the final scores at 1280x800, inside the host frame, as `night_scoreboard_card_test.dart` mounts them.
  1. Leader: P1 alone. Points 9/5/2/2 per round over 3 rounds, totals 27/15/6/6. Expected crowned set `{'p1'}`.
  2. Tie on top: P1 and P2 both crowned. Points 5/5/1/0 per round over 3 rounds, winners P1 and P2, totals 15/15/3/0. Expected `{'p1', 'p2'}`.
  3. Leaver: P1 finishes top (27), then its controller is removed and the host emits. `championsAmong(remaining)` still names `{'p1'}`, the crown stays on P1 and the row `nightRow-p1` stays on screen.
  - Each test asserts the crowned set equals `night.championsAmong(players)` (via a helper that fails if no night is running), and states the expected set literally.

## Self-check (review-rules part A)

1. Host setups: the test mounts a TV-sized host at 1280x800, with four joined phones. Every `pumpHost` setup in the existing card test is the same kind. Not a new host setup.
2. Kept state: no new kept state. The night and its `seen` map are the existing ones; the leaver test shows P1's row and crown persist after leaving (test 3).
3. Combinations: the crown depends on `over` (the final scores), so it is off between rounds (existing frame tests cover that: `night_scoreboard_frame_test.dart` expects no crowns mid-night). Leaver is test 3. Pause menu, "Get ready", dropped link and results are not touched by this change.
4. Files: only the two allowed files plus this report.
5. Stops: none needed.
6. Looks: no size-specific layout code changed. Only one device size (1280x800) is used, because the crown logic is not layout; the layout tests in `night_scoreboard_frame_test.dart` already cover the sizes. The crown's size and the row heights are unchanged.

## Checks

- `tools/mine.sh`: first run failed on `unchecked_use_of_nullable_value` (the night state is `NightState?`) in my test; fixed with a helper that fails if no night is running. Second run: `OK 44 tests packages/party_host`, `RESULT: ok: 6 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- The new file's tests were run in that check; I did not run them on the base, so the "fails on the base" claim is not measured (exempt above).

## Questions and suggestions

1. Tests 1 and 2 use `winners` to pick the round winners; the points map alone decides the champions. If a reviewer wants the awards to matter, they are not part of this rule.
2. The `_NightInFrame` and `_pumpFinalScores` helpers duplicate `night_scoreboard_card_test.dart`. A shared support helper would remove the copy, but that touches files outside `allow:`, so I left it.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
night scoreboard: crown the champions via championsAmong

The final scores crowned and marked the winner by row place 1. Use
NightState.championsAmong, the Quick night rule, so the scoreboard and
the champion share one rule (code-health night1b). Ties still share the
crown; a leaver who finished top keeps it. Behaviour is unchanged on the
base; new widget tests pin the wiring, the tie and the leaver.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n1j: the final scores crown and mark the winner through NightState.championsAmong (done, widget tests for leader, tie and leaver); open: none for this job.

## Delete

- none
