# Review: M14 bugs11 b021-end-night-2 (B-021 phase 2, End night on Shape Race's night results)

## Summary

Verdict: **small fixes** — 0 must, 1 should, 4 could. The job does what the brief asks: End night beside Next on a night's Shape Race card except after the last round, `endNow(result.round)` then the reveal over `isGamePickerRoute`, the split is a pure move plus the new wiring, and the sizes hold (puzzle_screen 371, results widgets 248, new part 34). The self-check's claims about state, hosts and `endNow`'s guard are true against the code.
- The report's self-check 4 is not true: `run.log` lists five `site/shots/*.png` changed outside `allow:` (dropped; the job's result was 4), the same finding phase 1's review made.
- The phone-host case runs at the harness's 960×540 default and `shareView` changes no layout, so it repeats case 1's assertions and the night's two-button `Row` is never laid out at a phone size.
- `_showAfterNight` is now a second copy of `game_screen.dart`'s, and the shared-widget question phase 1's review left to phase 2 was answered by copying the row, with no decision line.

## Findings

- **should** docs/briefs/m14/bugs11/b021-end-night-2-report.md:48 says only `allow:` files changed, but docs/briefs/m14/bugs11/run.log:57 records five `site/shots/*.png` changed outside the list (dropped by the runner; the job's result was 4) → say in self-check 4 what those five files were and that a check generated them rather than the worker writing them.
- **could** packages/party_host/test/end_night_puzzle_test.dart:100 runs the phone-host case at `pumpHost`'s default 960×540 (host_harness.dart:54), where `shareView` changes no layout, so it asserts the same two keys as case 1 and the report's "no overflow" says nothing about a phone's width → run it with a phone surface (`size: const Size(852, 393)`, as screen_fit_test does), where the night's two-button Row is the risk.
- **could** packages/party_host/lib/src/ui/puzzle_screen_results.dart:20 is a second identical copy of `_showAfterNight` (game_screen.dart:281), so a third game copies it again → put the one helper beside `isGamePickerRoute` in `leave_round.dart` when a brief allows that file.
- **could** docs/design/party-night.md:108 still says the Arena's results card ends with "Next" in a night, contradicting line 62's "both games' cards" (phase 1's review raised the same line) → add "Next and End night" there.
- **could** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:109 adds End night with no focus pin for this card, where phase 1 pinned the remote's Right walk from Next on the Arena card (menu_press_test.dart:69) → add a case that presses Right on the results and expects the End night button focused.

## Decisions to confirm

- The night's Next/End night row is built in each card (`arena_results.dart:193`, `puzzle_results_widgets.dart:104`) rather than shared; phase 1's review asked phase 2 to decide this, and a shared home would be a file outside both jobs' `allow:`, so confirm where it belongs before a third game's card.
- `lastRound` is now a required parameter on both cards' results widgets (`_Results` here, `ArenaResults` in phase 1); confirm the flag stays per-card rather than the widget asking the night itself.
- The button lives in `puzzle_results_widgets.dart` rather than `_ResultButtons` because `puzzle_screen_widgets.dart` is outside `allow:` (report decision 1); the next job that touches `_ResultButtons`'s "first button alone, Next" doc (report question 2) should move it there.
- The round's points are read from the match rather than pinned (report decision 4), so the report's "Final standings 13" and "P1 wins Comeback alone" are claims the test does not check; confirm that is wanted, as in phase 1.
- The moved `_leaveForGames` and the new `isGamePickerRoute` use resolve through `pause_menu.dart:25`'s `export 'leave_round.dart'` (imported at puzzle_screen.dart:32), not an explicit import; confirm that transitive export should stay the way the puzzle library gets it.

## Could not check

- Which three of the new file's four cases failed on the old code, and why: the runner's old-code run is not in `run.log`.
- I did not re-run `format analyze host phone`; the runner's exit (4, churn only, not 5) is my evidence they passed, and I did not count the 476/475 tests.
- Whether the round on the card really scores 5 and P1 really wins exactly one award, so whether 13 is right: the test computes both from the night rather than pinning them.
- A real phone width's layout of the card: no test lays the night's Shape Race results out below 960×540.

## Commit message

review b021-end-night-2: small fixes, no must

The Shape Race night card's End night works as the brief says: endNow
records and ends the night on the card's round, the reveal and final
scores follow, the last round keeps Next alone, and a phone host shows
it. Only report and test-hygiene items: self-check 4 misses the five
site/shots PNGs the runner dropped, the phone case runs at 960x540 and
repeats case 1, the focus walk to End night is unpinned on this card,
and `_showAfterNight` and the design doc's Arena line are copies left
to settle.

## Status row

B-021 done: End night on both night results cards, the Bumper Round's (phase 1) and Shape Race's (phase 2), each ending the night on the round just played with the reveal and then the final scores following; tests + design §4 + this review. Open: this review's 1 should (report self-check 4) and 4 coulds (phone-size case, shared `_showAfterNight`, design line 108, focus pin); phase 1's open questions stand.

## Delete

- none
