job: m12 step7 s7e G4 — the clock and score beside the board; the tray row without overlap
stop: after G4.
read: docs/design/m12-phone-layout.md §0.7c (the owner's option 3, the contract for this job) and §1–§2 · docs/design/m12-hud-options.png (option 3, read it as an image) · docs/briefs/m12/s7c-report.md · docs/briefs/m12/bug-1107-fix-report.md · docs/coding-guidelines.md · packages/puzzle_game/lib/src/{split_layout,puzzle,camera,view,match_painter,puzzle_painter,game,tray}.dart · packages/puzzle_game/test/{split_layout_test,camera_test,view_test,puzzle_module_test}.dart · controller_app/test/puzzle_size_test.dart

do:
1 `_computePhones`: no `hudWidth` area; the tray row spans the world's width and packs with `trayOverlap` 0; width = max(board + margins, row + margins); height unchanged; `SplitLayout.hud` goes (or is always null — say which). The rules' start-time packing follows the same width and overlap, as before.
2 `camera.dart`: a pure `PuzzleCamera.hudPlace(layout, camera, box)` → where the HUD goes in px and in which form (one line, two lines, or over the board's corner), from contract §0.7c; named constants with units and reasons (`hudTopFraction` 0.14, the text sizes as fractions of the box height, the margins, the widths that pick the form).
3 `match_painter.dart`: the phone HUD draws there, in screen space, after the world: clock, score, time bar (green; red while warning). Solo "0 of 4 placed"; race "You 2/4 · Right 3/6" (the camera's side first); `whole` on phones: one HUD for the match with both counts ("Left 2/4 · Right 3/6"). `phoneHud(...)` keeps returning the texts for tests.
4 The screen layout: unchanged.
tests:
- split_layout_test: the phones rules as before but with the new width and no overlap (each tray box apart from the next by at least `trayGap`), no HUD area; height per puzzle unchanged from s7c.
- camera_test: `hudPlace` at 852×393 (one line, left of the world, top at 0.14 × 393 = 55.0), 667×375 (two lines), a narrow box where it falls back to the board's corner, and 1024×768 `whole` (left of both worlds); px/unit for `side` unchanged where the phone's height decides (say which cases changed and why).
- view_test: the HUD texts (solo, race, whole); a phones picture draws without exception at 852×393 and 667×375.
- puzzle_size_test still passes; list any mm that changed (old → new).
- existing: list every expected value that changes, old → new.
in the report: line counts (flag > 300), test counts per check before and after, the HUD's px rects at 852×393 and 667×375 for the tree (solo) and the house (race).
rules: no lib file over 400 (tests 500); `split_layout.dart` must not grow · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s7e-report.md · packages/puzzle_game · controller_app/test/puzzle_size_test.dart
check: format analyze puzzle host phone
report: docs/briefs/m12/s7e-report.md
