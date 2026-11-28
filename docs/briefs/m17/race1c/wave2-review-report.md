# wave2 review: race1c r3f (pop confetti and the "who held it" line)

## Summary
Verdict: small fixes. Counts: 1 must, 8 should, 3 could.
Top three:
1. present_pop_widgets.dart:126 bare magic numbers in the confetti depth formula (guidelines §2).
2. puzzle_results_widgets.dart:39,72,134 +3 lines against the brief's "at most 2, net 0" (file now 380, at the gate).
3. present_pop_widgets.dart:19 the `pops` ValueNotifier is never disposed; `_PuzzleScreenState.dispose()` does not release the tracker.

## Findings
- **must** packages/party_host/lib/src/ui/present_pop_widgets.dart:126 bare `0.4`, `0.6`, `5` and `4` in the confetti depth formula break the magic-number rule → name them as documented constants at the top of the file (e.g. a depth-levels count and a near/far share).
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:48 `_goldenAngle` has no unit in its name (rule §4, Rad) → rename it `_goldenAngleRad`.
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:19 `PresentTracker.pops` (a ValueNotifier) is never disposed, and `PresentTracker` has no dispose (rule §5) → add `dispose()` to `PresentTracker` and call it from `_PuzzleScreenState.dispose()` (packages/party_host/lib/src/ui/puzzle_screen.dart:178-183).
- **should** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:39,72,134 the brief allowed at most 2 added lines and net growth 0; the file went 377 → 380 with 3 added lines and nothing moved out → move at least 3 lines of the file out along a seam, or have Claude accept the overrun.
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:37,100,353,371 the brief allowed at most 3 added lines in this file; 4 were added (net -1 after `_clocked` moved) → have Claude accept the 4th line, or cut one.
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:159-161 `PresentHeldLine` reads `tracker.heldAtPop` once at build and does not listen to `tracker.pops`, so the line is right only if the results mount after the last feed; no test covers that order → rebuild on `pops` (a ListenableBuilder), or add a test that the line shows when the results mount after the pop.
- **should** docs/briefs/m17/race1c/r3f-report.md:23-29 (self-check) line 1 answers only the looks; rule A1 (TV/PC host, phone "Play on this phone", phone "Show on this device", joined phone, one build older) is not answered; rule A3 names only pause and results, not host away, player away, "Get ready", dropped link or leaving → add one line per item with its test, or "not affected" with the reason.
- **should** docs/briefs/m17/race1c/r3f-report.md (whole file) no format, analyze or test results are reported, though the brief names `format analyze` and the review rules ask for the outcome → add the command output lines.
- **should** packages/party_host/test/present_pop_widgets_test.dart:80 no test proves that unmounting `PresentConfetti` releases its listener and its controller, or that the tracker's notifier is released (guideline §5 and §9 require a dispose test) → add a test that disposes the stage and checks no listener or animation remains.
- **could** packages/party_host/lib/src/ui/present_pop_widgets.dart:78-83 `didUpdateWidget` handles a swapped tracker, but no caller swaps trackers and no test reaches the branch (a dead branch, §2) → drop the branch if no caller needs it, or add a test that pins it.
- **could** packages/party_host/lib/src/ui/present_pop_widgets.dart:42 the piece is a fixed 14 px, not sized from the box or `pxPerMm` (§6 sizing rule), and the doc's "three metres on the TV" is not checked anywhere → size it from the box, or keep the px and reword the doc to the reason.
- **could** packages/party_host/test/present_pop_widgets_test.dart:63 the held-line test names only the Right side, so the Left wording is untested → add a Left case in the same test.

## Decisions to confirm
- `_clocked` was moved from puzzle_screen.dart to puzzle_screen_results.dart (r3f-report.md:8). It was not in the brief; it was done to make room in the 380-line file. Claude should confirm the move.
- The confetti is mounted outside the `Pausable` paused state (puzzle_screen.dart:353), and the tracker is fed before the paused return (play_view.dart:190). So a burst runs over the pause menu and the results, and a pop started before a pause finishes during it. Confirm that is wanted; if not, the burst needs the pause as an input.
- The piece size is fixed at 14 px (present_pop_widgets.dart:42) and not scaled by `pxPerMm`. Confirm for the phone and TV sizes.

## Could not check
- This was a read-only review: no `dart format`, `dart analyze` or tests were run here. The only test evidence is the runner's log (run.log: "tests-first ok ... fails on the old code", result 0).
- `(1 - progress).clamp(0, 1)` is passed as `alpha:` (present_pop_widgets.dart:128); its type was not checked against this SDK here.
- How the burst looks under the TV look and the menu look was not seen; no screenshot exists.
- The order of the tracker feed and the results mount within one tick was not traced through every finish path of the play view.

## Commit message — a draft
review: wave2 race1c r3f, findings only, no code change

Reviewed the r3f job (pop confetti and the held-line results text)
against the coding guidelines, the review rules and its brief.
Verdict small fixes: one magic-number break, two brief line-limit
overruns, an undisposed notifier, a missing dispose test, and report
gaps (self-check A1/A3, check results). Twelve findings in the report.
Only the review report was changed; no code was touched.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row
wave2 review of r3f: done (verdict small fixes; 1 must, 8 should, 3 could); open: the magic numbers and disposal fixes, the brief line-limit overruns for Claude to rule on, and the report's A1/A3 and check-result gaps.

## Delete
- none
