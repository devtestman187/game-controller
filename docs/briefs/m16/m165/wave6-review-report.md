# m165 wave 6 review (c1, c2, c3)

## Summary

small fixes
Counts: must 0, should 3, could 4.
1. controller_app/lib/src/ui/bar_connection.dart:104 says the chip is at least 48 dp square even when the row is full, and c3-report.md:6 says the same; at 568x320 TV it is 35.9 dp wide (c3's own Open item).
2. The 170 dp threshold (bar_connection.dart:90) ignores the ping text: with the ping beside, the chip shows "Android TV · 9 ms", which is longer than the 195 dp the comment uses, and no test covers that band.
3. controller_app/test/connection_chip_test.dart:31 skips the label check when the chip has no Text and asserts no tooltip, so a dot-only chip with no tooltip passes.
Re-derived by hand: c1 totals (8/18, 2/18, today null 1/18 and 17/18, fits where null 1 and 2) and c2 free widths (right edge minus left edge) agree with the tables.

## Findings

- **should** controller_app/lib/src/ui/bar_connection.dart:104 The comment "at least 48 dp square, even when the row is full" is false at 568x320 TV, where the room is 35.9 dp (the ConstrainedBox is capped by the Flexible's max width, as the base shows) → reword it to name the case the row cannot fit, and make c3-report.md:6 say the same.
- **should** controller_app/lib/src/ui/bar_connection.dart:90 The threshold uses the host-only width, but with the ping beside the chip shows `PhoneText.linkWithPing` (packages/party_host/lib/src/text/phone_text.dart:139, "Android TV · 9 ms"), which needs more than the 195 dp the comment gives, so a room of 170 dp up to that width is cut with no test → measure the widest text the chip can show (TextPainter, or the ping form's width) and add a test with the ping beside at a room in that band.
- **should** controller_app/test/connection_chip_test.dart:31 `if (label.evaluate().isNotEmpty)` skips the whole label check when there is no Text, and nothing asserts the tooltip (chip_readable_test.dart:46-50 does) → assert the Tooltip with its message, as chip_readable_test.dart:48-50 does.
- **could** controller_app/test/mirror_strip_proof_test.dart:156 The table test has no expect, so it passes whatever the rows are; the brief asked for the table, so add `expect(rows, hasLength(puzzles.length))` to keep it from passing on an empty or partial run.
- **could** controller_app/test/mirror_strip_proof_test.dart:34 `raceText` hand-copies the HUD text ("You 0/n · Right 0/n"), which matches packages/puzzle_game/lib/src/phone_hud.dart:35 and :40 today but would drift silently → reuse the HUD's text builder if it is public, or cite phone_hud.dart in its doc.
- **could** controller_app/test/mirror_strip_proof_test.dart:25 `'../packages/puzzle_game/puzzles'` is a path literal, and lines 26 and 28 cast decoded JSON with `as` without validation → read the path from one named constant with its reason, and check the decoded types before the cast (test fixture only).
- **could** controller_app/lib/src/ui/bar_connection.dart:89 The LayoutBuilder's `context` shadows `_chip`'s `context` parameter; the inner one is the one `openConnect` needs → rename the parameter to `chipContext` or drop the outer one.

## Decisions to confirm

- c3: `iconOnlyChipBelowDp` is 170 dp, a named constant, not a TextPainter measure; it is only right if the ping form is not longer (finding 2).
- c3: `ref.watch(demoProvider)` moved to the top of `_chip` (bar_connection.dart:85), so the chip now rebuilds on demo changes while connected. Not in c3's Decisions or Files list.
- c3: 568x320 TV chip and pad stay skipped, which needs a row or badge job; the owner decides that job.
- c1: Select and Start are computed with `stickLayout(game box)` and overlap the board in 18/18 puzzles at both sizes (c1-report.md Question 1); the answer depends on whether the on-screen layout is meant.
- c1 and c2: the measurement tests print with `stdout.writeln` (mirror_strip_proof_test.dart:158-171, top_bar_free_width_test.dart:74-77). The worker rules call print in tests debug code, but the brief asked for the table; keep it, or move the table into the report.
- c2 ran `tools/mine.sh` instead of the brief's `check: format analyze phone` (c2-report.md:58); c3's report lists no `phone` check (c3-report.md:10).

## Could not check

- No test was re-run (read-only job); the pass counts (76 for c3, 12 for c2, 4 for c1) are the workers' claims.
- Whether 195 dp is the true width of "Android TV" (bar_connection.dart:27, an existing comment) was not measured.
- The bar widths at which the ping sits beside the chip, and so the width of the ping form, were not measured (finding 2).
- The screen-reader label of the icon-only chip (its Tooltip) was not checked on a device.
- The mirror floor formula (mirror_strip_proof_test.dart:92) matches packages/puzzle_game/lib/src/camera.dart:248 by reading; not run.

## Commit message

m165 wave 6 review: c1-c3 checked, no must findings

Reviews the wave 6 jobs c1 (mirror strip measurement), c2 (compact bar
free width) and c3 (connection chip icon-only below 170 dp) against the
guidelines, the review rules and their briefs. Writes findings only:
0 must, 3 should, 4 could. The should items: the 48 dp comment and report
claim at 568x320 TV, the ping text the 170 dp threshold ignores, and a
label check in connection_chip_test that passes without a tooltip.
No code changed.

## Status row

m165 wave 6 review (c1-c3): done, 0 must, 3 should, 4 could; open: chip 48 dp claim at 568x320 TV, 170 dp threshold vs ping text, connection_chip label check without tooltip assertion; owner: keep printed measurement tests, Select/Start body.

## Delete

- none
