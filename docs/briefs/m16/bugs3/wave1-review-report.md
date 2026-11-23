## Summary

Verdict: small fixes
Counts: must 0 · should 5 · could 2
1. The report's commit draft (b037-report.md:40), status row (:46) and summary (:10-11) give the rank font as 0.55 / 17.6 px, under the floor. The code at 6e6f32a is `scoreRankTextShare = 0.625` (score_row.dart:50), i.e. 20 px. Only the driver note (:61-63) is right.
2. The self-check (b037-report.md:27) says host screens are not touched. `ScoreRow` also draws the night final (night_scoreboard_widgets.dart:113) and the arena results (arena_results.dart:225, 247), so the change reaches them.
3. `phone_fit_matrix_test` (the 20 px floor, night-final) was not in the run list (b037.md:11) and failed at 0.55 (b037-report.md:63). The outline check in the new test (score_row_winner_fit_test.dart:94-97) only checks the text box against the disc's square, so it cannot show the number clears the outline.
Old-code check (computed, not run): old badge 58 px fails (a); old crown overlap 21 px fails (b); old rank font 22 px (toy_type.dart body, frame) with default line height gives a box over 19.2 px, so (c) fails. All three fail on the old code.

## Findings

- **should** docs/briefs/m16/bugs3/b037-report.md:40 Commit draft says the rank font is "capped at 0.55 of the disc"; the code is 0.625 (score_row.dart:50) → rewrite the draft line to 0.625 / 20 px.
- **should** docs/briefs/m16/bugs3/b037-report.md:46 Status row says the rank is 17.6 px, "under the 20 px floor"; the code gives 20 px, which meets it → rewrite the status row; also fix Summary lines :10-11 and Hand-over :18-19, which still say 0.55 / 17.6 px.
- **should** docs/briefs/m16/bugs3/b037-report.md:27 Self-check item 1 says "Phone, TV and peer-build host screens are not touched", but ScoreRow is on the night final (night_scoreboard_widgets.dart:113) and arena results (arena_results.dart:225, 247) → answer per setup with the test that shows it, or write "not tested".
- **should** docs/briefs/m16/bugs3/b037-report.md:12 "49 tests … all passed" omits `phone_fit_matrix_test`, which the driver found failing at 0.55 (:63); the brief's run list (b037.md:11) left it out → add it to the run list and run it at HEAD before the commit.
- **should** packages/party_host/test/score_row_winner_fit_test.dart:88-101 The test is named "sits inside the disc and its outline", but lines 94-97 check only the text box against the disc's bounding square; the box corners sit 14.1 px from the centre, which can cross the outline ring at radius 16 minus `outlineWidth` → check the glyph or the corners against the circle inset by `look.sizes.outlineWidth`, or rename the test to say "its square".
- **should** docs/briefs/m16/bugs3/b037-report.md:58 (Q5) `tools/mine.sh` churn step reverted 22 files, and the docs/design PNGs no longer show in `git status` (the nine remaining M entries are the site/shots and tv_test_app files). Uncommitted work may be lost → owner to restore from their copy; the churn step should not revert files outside the job's allow.
- **could** packages/party_host/test/score_row_winner_fit_test.dart:21 `_rankTextMaxShare = 0.625` repeats `scoreRankTextShare` (score_row.dart:50); changing the cap leaves this test unchanged → reference the lib constant if it is reachable from the test.
- **could** packages/party_host/lib/src/ui/score_row.dart:369 The file is already over the ~300-line target and the job added to it without a split → split the medal disc or the crown seat into a part file the next time it is touched (code-health).

## Decisions to confirm

- score_row.dart:50 The rank share is 0.625, not the brief's 0.55 (b037.md:10): the driver changed it to pass the 20 px floor. The number now fills 62.5% of the disc; the owner should confirm the size and that the glyph clears the outline (no test shows this).
- score_row_parts.dart:21, 37-38 `rankLineHeight = 1.0` is not in the brief; it trims the leading so the height check holds. Needed by the check, but not listed in the brief's changes.
- score_row.dart:343-353 The crown is 30 x 21 px and sits 17 px above the disc with `Clip.none`, so it reaches about 7 px above the 68 px row if the badge is centred. Owner to accept this or shrink the crown (report Q2).
- arena_results.dart:225, 247 `arenaCrownPx` is unchanged though the brief lists it (b037.md:4); report Q3. Confirm that the arena winner keeps its size.

## Could not check

- docs/briefs/m16/bugs3/run-findings.md does not exist, so there are no run-findings entries to check.
- I ran no tests (reviewer installs nothing). The 49-test figure and the "fails on old code" claims rest on the report; my old-code numbers above are computed from the code.
- The crown's overflow above the row is not rendered on any host screen.
- The worker's "22 files" and the lost docs/design changes cannot be verified from here beyond the status shown above.
- I read docs/review-rules.md in full and used the worker extract for docs/coding-guidelines.md, not the full guidelines file.
- The rank's font for a winner is `scoreWinnerNamePx` (score_row.dart:248), which I did not trace through; the old-code figure uses the body size only.
- Whether `pubspec.lock` changed (report Q6): `git status` now shows no such change.
