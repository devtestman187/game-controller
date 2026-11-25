# M16 wave1-789 f1 — report

## Summary

- Both tie tests run again: the skips are gone, and the `BISECT-TEMP` early return that made the no-tie test check nothing is gone too.
- The tie overflow was a test setup fault, not a reveal fault: the flow test did not load the look's fonts. No lib file changed.
- `_playNight` is split into `_mountReveal`, `_expectRevealStep` and `_expectFinalScores`; the helper uses `NightText.notWon`.
- `tools/mine.sh`: format, analyze, and 4 tests OK. `night_reveal_tie_test.dart` (not touched): 6 tests pass when run directly.

## Findings for the tie overflow

- The failure: `A RenderFlex overflowed by 11 pixels on the bottom`, from the `Column` at `toy_card.dart:129`, inside the reveal card (`ToyCard` key `nightReveal`). The exception arrives on the first pump after the reveal mounts, so the card is the first reveal, Best Helper, which has two winners (P1 and P2).
- It shows in both looks (I ran the tie case with the TV look alone: same 11 px overflow). It also shows framed as a phone host at 960x540 with the TV look. So the look and the frame do not cause it.
- Why `night_reveal_tie_test` passes: it calls `setUpAll(loadLookFonts)` (`test/support/toy_fonts.dart`), and its comment says the test font draws every letter as a full box, so text measures wider than on a device. `night_awards_flow_test` did not call it. Adding that one line makes all four flow tests pass at 960x540 and at 640x360 as a phone host, in both looks.
- Cause: inferred from the fix, not measured line by line. The likely mechanism is that the un-fonted text is wider, so the reason and points lines wrap, and the card's column gets taller than its room. I did not confirm the wrap itself.
- Decision: the setup was unrealistic, so I fixed the setup and left the reveal code alone. The brief's own rule, change lib only for a real layout fault, did not apply once the setup was realistic.

## Files changed

- `packages/party_host/test/night_awards_flow_test.dart`
  - Removed both `skip: true` and their comments.
  - Removed the `if (i == 0) return; // BISECT-TEMP` line. This was a debug early return: the no-tie test passed only because it returned before its first check. It now checks every reveal and the totals.
  - Added `import 'support/toy_fonts.dart';` and `setUpAll(loadLookFonts);` with a comment saying why (the setup fix above).
  - Split `_playNight` (was 59 lines) into `_mountReveal` (the reveal's mount, join, start, rounds), `_expectRevealStep` (one award's checks and its stay) and `_expectFinalScores` (the scoreboard and totals). `_playNight` is now about 25 lines; each helper is under 40.
  - Replaced the literal `'Not won tonight'` with `NightText.notWon`.

No other file changed. `night_reveal_widgets.dart`, `night_reveal_screen.dart`, `night_reveal_tie_test.dart` and `night_reveal_test.dart` are untouched.

## Computed test values

- Tie night (`_tieNight`): award winners are Best Helper P1 and P2, Comeback P1, Sharpshooter P1. Round points P1 11, P2 7, P3 1. Wins P1 3, P2 1, P3 0. Final scores: P1 11 + 3 × 3 = 20, P2 7 + 3 × 1 = 10, P3 1. The file's own comment has the same numbers, and the test checks them through `nightTotal-<id>`.
- No-tie night (`_noTieNight`): Cat Catcher nobody (`Not won tonight`, stays `nightAwardMissedRevealMs`); Comeback and Sharpshooter P1. P1 11 + 3 × 2 = 17, P2 7, P3 1.
- Test results: `flutter test test/night_awards_flow_test.dart` 4 of 4 pass. `flutter test test/night_reveal_tie_test.dart` 6 of 6 pass (the footer band test and the five tie sizes).

## Self-check (review-rules part A)

1. Host setups: the tied and no-tie night run at 960x540 (TV and menu looks, no frame), and the 640x360 phone host (menu look, framed) runs the no-tie and tied nights. Tests: `a night with a tied award...`, `a phone host at 640x360 plays the tied night...`.
2. Kept state: the night starts on the start card and the reveal is a fresh mount; the test does not check teardown beyond the existing `pumpWidget(SizedBox.shrink())`.
3. Combined states: not in this job's scope (the test covers the reveal and the scoreboard only).
4. Folder and allow list: only `night_awards_flow_test.dart` changed.
5. Stop: no lib change was needed, so nothing was stopped.
6. Looks: the flow test runs the menu and the TV look; the tie test runs the TV look at five device sizes.

## Hand-over

Nothing is open in this job. The tie fix is verified by the test run above, not by a device.

## Questions and suggestions

1. `night_reveal_widgets.dart:200`: the points line (`NightText.awardPoints`) has no `maxLines`, unlike the other reveal lines. On a device with a narrow card it could wrap and push the card taller. I did not change it because it is not the cause here and the brief allowed lib edits only for a real fault. Suggest a `maxLines: 1` (with ellipsis), decided by someone who owns the reveal.
2. The no-tie test passed before only because of the `BISECT-TEMP` return, so earlier "green" results for it did not check the reveal. Worth knowing when reading older run logs.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: the awards flow runs the tie cases and checks every reveal

Un-skip the two tie tests in night_awards_flow_test. Their overflow came
from the test: the file never loaded the look's fonts, so the reveal's text
measured wider than on a device. Load them as night_reveal_tie_test does.
Remove the BISECT-TEMP early return that made the no-tie test check
nothing. Split _playNight into mount, reveal-step and final-score helpers,
and use NightText.notWon.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave1-789 f1: awards flow test runs both tie cases (both looks, 640x360 phone host), no skip or debug return left; the tie overflow was the missing look fonts in the test, not the reveal. Open: the points line in night_reveal_widgets.dart:200 has no maxLines (suggestion only).

## Delete

- none
