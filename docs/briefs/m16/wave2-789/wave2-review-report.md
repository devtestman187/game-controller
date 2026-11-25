# Review of wave2 (n8b0, n9sr)

## Summary

small fixes
must 0 · should 5 · could 2
- **should** The n9sr brief's item 3 is only partly met: the round label is passed to the one-board painter only (match_view.dart:210), so split and phone screens show no "Round N of M".
- **should** The label's "both set" rule in PuzzlePlayView (play_view.dart:196-199) has no test; the 12 tests pass with that getter returning null.
- **should** n8b0's flow tests never ran (host_mode_test, host_start_log_test), yet its draft says "Behaviour is unchanged".

## Findings

- **should** packages/puzzle_game/lib/src/match_view.dart:210 The brief's item 3 asked for the label through view.dart and match_painter.dart; only the one-board PuzzlePainter gets it, so a two-board or phone-host night shows no round label → Claude to decide (see Decisions); if the label should show there, pass it to MatchPainter and draw it in the strip and phone HUD.
- **should** packages/puzzle_game/lib/src/play_view.dart:196-199 `_roundLabel` (both-set rule and the 'Round $round of $rounds' text) is covered by no test, so a getter that always returns null leaves all 12 round_label_test cases green → add a PuzzlePlayView widget test with round 2 and rounds 3 (label drawn) and with only round set (no label).
- **should** docs/briefs/m16/wave2-789/n9sr-report.md:77 The commit draft says the split and phone HUDs show no label "(owner decision)", but Question 1 (line 56) says that decision is still open → reword the draft to "pending owner decision".
- **should** docs/briefs/m16/wave2-789/n9sr-report.md:62 Self-check says the three tv_test_app/windows/flutter generated files "are now clean", but `git status --short` run for this review lists them as ` M` → check the worktree and correct the sentence.
- **should** docs/briefs/m16/wave2-789/n8b0-report.md:51 The draft says "Behaviour is unchanged", but the two tests that pin the flow did not run (n8b0-report.md:17) → state it as untested, or run the two tests on a worktree that loads the puzzle asset.
- **could** packages/puzzle_game/test/round_label_test.dart:56-67 `differs()` computes `top` and returns it, and no test reads it → drop the field.
- **could** packages/puzzle_game/lib/src/board_hud.dart:80-94 `_labelledName` rebuilds the TextPainter that text_paint.dart:51-63 `_layout` builds (same fontSize, colour, height 1), because `_layout` has no maxWidth or ellipsis → add those as optional parameters to `_layout` in a later job (text_paint.dart is outside this job's allow:).

## Decisions to confirm

- Split and phone screens show no round label (n9sr-report.md Question 1): the brief asked for it through match_painter.dart; the report leaves it open. Phone "Play on this phone" with one board also shows none.
- The planned test "without them draws no round text" was dropped (n9sr-report.md:24); the picture tests cover the no-label path, but nothing asserts it directly.
- n9sr's ellipsis is applied to the whole "Round N of M · name" string, so a long label cuts the round text too, not only the name (board_hud.dart:56, 80-94). The brief allowed this ("cut the label with an ellipsis").
- n8b0 reads `hostingProvider.notifier` after the mounted check instead of before the sheet (host_launch.dart:14; connect_panels.dart:107-109). The report says this is safe, and I agree: `ref` is only read after `context.mounted` is true.
- `tools/mine.sh` reverted three tracked generated files under tv_test_app/windows/flutter/ that were already modified when the wave started (n8b0-report.md:31, n9sr-report.md:62); git status still lists them as modified. Whether the runner should revert pre-existing edits is for the owner.

## Could not check

- host_mode_test and host_start_log_test: no run here. The reports say setUpAll fails on `packages/puzzle_game/puzzles/index.json`, but that file exists and packages/puzzle_game/pubspec.yaml declares `puzzles/` as an asset, so the cause is not visible from reading. Whether main fails the same way is unknown.
- docs/briefs/m16/wave2-789/run-findings.md does not exist, so no runner findings were read.
- The other 6 of the 18 tests in the n9sr run were not broken down by the report and were not checked.
- The label on a real TV and a narrow phone: no device check; the tests only prove the label stays left of the clock.
- No tests were run: this is a read-only review (git status and greps only).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

review of wave2 (n8b0 n9sr): findings only

Reviews the two wave-2 jobs against their briefs and the coding and
review rules. Adds docs/briefs/m16/wave2-789/wave2-review-report.md.
No code or other document changed. Findings: 0 must, 5 should, 2 could.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave2-789 review: n8b0 and n9sr reviewed (0 must, 5 should, 2 could); open: label missing on split and phone screens (owner), label rule untested, n8b0 flow tests not run here.

## Delete

- none
