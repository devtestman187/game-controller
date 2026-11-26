# m16 tail report (Nov 26)
- Jobs: m1 measure (Haiku, 16 turns, 4.4 min, c3d0b71a), s1 Start into the game bar (Sonnet, 47 turns, 4.9 min, 36778118; first try parked: class brief, controller_screen.dart missing from allow since the bar is a part file; repaired once, ladder 2), s2 rightPadRects drops Start (Haiku, 29 turns, 5.0 min, 4f778134). Sonnet share 1 of 3 (new widget test file). No hand-fix.
- Job 3 (mirror placement strip -> corner -> gap -> null) BUILT (see addendum); the owner gate on small phones is open, option (a) below is a separate revertable commit.
- Measured (game box = screen minus 52 px bar, sticks; m1-report.md): option A (top-right strip + ring corner) places 16/18 at 956x440 and 1/18 at 667x375; today places 17/18 and 1/18; either spot 18/18 and 2/18. Reconciliation: REPORT m165 :106 (null 1/18, 17/18 at 667) is right (real box); :75 (14/18, 3/18) was measured in the whole screen, 52 px too generous (m1 whole-screen counts reproduce it).
- Review (REVIEW.md, run review by Haiku): must 0; finding 1 (hosting lobby loses Start) invalid, no pad is built in phase none; rest minor to code-health, report Summary fixed by hand. Open owner questions: none beyond the option A gate.
- check.sh: All checks passed (104s). 4 job rows in run.log; agent-cost since 11:00: total $1.74 (sonnet $1.39).
- Fixed, unverified: Start in the bar (s1) and the right rects without Start (s2): needs device check at 568x320.
- Proposed lessons: none. Calls: driver about 40; waiters 2 (7 and 7 tool uses). 
- proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
- no background command of mine is still running

## Addendum (Nov 26, job 3 and measures; inline, no runner)
- Job 3 BUILT: mirrorPlace order is now strip (top right, 8 px inset, over the ring's empty corner; only tried where hudRects holds a round control) -> today's corner -> today's gap -> null. Code: camera.dart (+5 lines, 376) and camera_fit.dart (_stripRect, _stripFitting; circles = square hudRects, a floating stick's zone is no circle and is ignored; obstacles tray, board, HUD, pad all with the 8 px air). The mirror takes no touch (the game draws behind the controls). At 956x440 (sticks) 16/18 mirrors move from today's spot to the ring corner (2 stay in today's spot); with 18/18 placed.
- Pin changed: packages/puzzle_game/test/hud_place_right_controls_test.dart (ring present => strip). New measure tests: controller_app/test/mirror_floor_proof_test.dart, bar_count_fit_test.dart.
- check.sh: All checks passed (259s). No worker, no run.log rows: inline work by the driver (kit allows inline).
- Fixed, unverified: strip placement on a device (please check at 667x375 and 844x390).
- Owner gate (low small-phone count at 2.2 mm) stays open: see numbers; nothing pushed.
- proc-sweep and background: none left (checks finished).

## Addendum 2 (Nov 26): option (a), the 1.5 mm floor
- Commits: 99eef25c (a bug found while taking the screenshots: the painter's mirrorPlace call lacked hudRects, so the real game drew no mirror where the view had fitted the strip; pinned by mirror_painter_ring_test.dart; keep it even if (a) is reverted) and the option (a) commit after it (revert that one alone to decline).
- Option (a): mirrorMinPieceMm 2.2 stays the cap (mirrorFraction unchanged); new mirrorFloorPieceMm 1.5 is the floor in mirrorPlace. mirrorPlace tries strip, corner, gap at the 2.2 floor first and only if none fits tries them again down to 1.5, so a phone where 2.2 fits is placed exactly as before (956x440: same rect and scale for all 18 puzzles, sticks and D-pad; pinned in controller_app/test/mirror_floor_pin_test.dart).
- Per-floor fit (placed of 18, sticks | D-pad; source test controller_app/test/mirror_floor_proof_test.dart, real mirrorPlace, game box = screen minus 52 px bar):
  - 956x440: 18|18 at 2.2, 1.8, 1.5
  - 844x390: 2.2 9|8, 1.8 18|18, 1.5 18|18
  - 800x360: 2.2 3|3, 1.8 18|15, 1.5 18|18
  - 667x375: 2.2 2|5, 1.8 11|16, 1.5 18|18
  - Height binds: of the 79 unplaced puzzle-cases at 2.2 mm across those six rows, 70 bind on the ring's height (strip too tall to clear the ring), 9 on other (board, pad or HUD width).
- Outline (mirror_painter.dart): the outline is 3 dp (look.sizes.outlineWidth / px, constant in screen px) and the shadow (3, 4) dp; a 1.5 mm piece is 9.45 dp, so unscaled they eat about a third of it and the shadow nearly half. Now both are scaled by lineShare = min(1, smallestPieceDp / 13.9 dp (2.2 mm)): at the floor 0.68, so outline 2.05 dp, shadow (2.05, 2.73) dp; at 2.2 mm and over unchanged. Neutral target lines (_targetPx, 1 px, faint) left as they are. Pinned in mirror_line_share_test.dart.
- Tests changed because (a) changes them: mirror_place_test (8-unit board now gets a mirror, 5-unit none; boat with the disc now gets a smaller mirror; 300 px box instead of 380), mirror_pad_test (the 15 and the 16:9 keep more puzzles; car and butterfly keep a mirror on the D-pad, smaller). New: floor pins, ring-less control keeps the same scale (restores held/free scale pin), mirror_no_touch_test.dart (touch on the mirror reaches the controls layer; the game has no touch handler).
- Shots (docs/briefs/m16/tail/shots/): dragon_667x375.png (mirror 52x47 px, smallest piece 1.57 mm), dragon_800x360.png (1.73 mm), dragon_956x440.png (2.55 mm, today's corner spot). Dragon is the puzzle with the smallest mirror at 667x375. Controls drawn as plain grey shapes; the test font draws the HUD text as blocks. Source: controller_app/test/mirror_floor_shots_test.dart.
- Batch review of 7427ff1f..tip: must-fix 1 (the painter's missing hudRects, fixed in 99eef25c); other: none must-fix (strip fit monotone in scale so the bisect holds; square hudRects treated as circles is an assumption a non-round square control would break, minor).
- check.sh after (a): see the final line of the hand-back.
