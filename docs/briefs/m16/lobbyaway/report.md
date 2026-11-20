## Summary
A round now waits only for the away phones it seats (M16 item 2); a lobby away-slot of a player the
round doesn't have pauses nothing, shows no away card and doesn't block the results' Back.

- players_away.dart (97 → 108): new `awayInRound(away, players)`, the away players whose id the round
  seats; null players = everyone (the Arena). The notifier's slot bookkeeping is untouched.
- ui/pause_menu.dart (400 → 376): `_stopped`, `_startPressed`, `build` use `_awayInRound`; the pause
  layout consts and `_resumers` moved to pause_menu_widgets.dart (95 → 130) to stay under 380.
- ui/puzzle_screen_results.dart (34 → 36): the Back block filters by `widget.teams.keys`.
- test/lobby_away_round_test.dart (new, 66): 3 tests; test/away_card_test.dart: "two away players get
  a line each" now drops P1 and P2 (both seated), where it had asserted the old rule with P3, unseated.

Back block: yes, needed. A lobby slot can be held before a round starts and still be held when it
ends, blocking Back for the rest of the 30 s; test 3 ("the results can be left…") fails on old code.

Computed values: test 1 — no `awayCard` after `startRound` + 500 ms, and the clock falls exactly
2000 ms over 125 × 16 ms frames. Test 2 — `openRace` + `holdSlot('p2')`: one `awayCard`, "Player 2 is
away", clock unchanged over the same 2000 ms. Old code: tests 1 and 3 fail, test 2 passes.

Self-check (review-rules A):
1. Host setups: one path for TV/PC/phone hosts (no branch); the Arena passes null players, unchanged;
   a joined phone only sends input. lobby_away_round_test.
2. Kept state: no new state; a slot still starts when the host reports the phone away and ends on
   return, grace or roster drop (PlayersAwayNotifier untouched). away_card_test #1.
3. Combinations: the filtered wait meets the pause menu, host away, the beat (`_stopped` feeds
   `_beat`), the results and leaving: pause_menu_test, ready_beat_test, puzzle_results_test.
4. Folder: only files in `allow:` written. 5. No file outside `allow:` was needed.

Questions: 1) "Go on without them" and the log's away line still cover unseated lobby slots — should they filter too?

## Hand-over

## Commit message
Only a round's own away players pause it

The round-blocking decisions (Pausable's stop, the away card, Start's block, the results' Back) use
only the away players the round seats (Pausable.players; null = everyone, the Arena). A lobby slot of
a player not in the round keeps their place for the 30 s grace but pauses nothing.
- awayInRound helper in players_away.dart; the notifier's slots are unchanged
- pause layout and _resumers moved to pause_menu_widgets.dart (pause_menu.dart 400 → 376)
- new lobby_away_round_test (2 of its 3 fail on old code); away_card_test's two-line test seats both

## Status row
- **M16 item 2 lobby-away fix (done; commit `<hash>`): only away players the round seats pause it** —
  `lobby_away_round_test` (3 tests), `tools/check.sh` green (12/12); open: real-device visual check.

## Delete
- none
