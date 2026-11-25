GATE: strip fits both dims for 8/18 at 956x440 and 2/18 at 667x375

## Summary

- New measurement test: `controller_app/test/mirror_strip_proof_test.dart` (4 tests, all pass). No lib change, no spot built.
- Game box = `Size(w, h - topBarHeightPx)`: 956x388 and 667x323 (topBarHeightPx 52). Pad and right rects are `leftPadRects` / `rightPadRects(screen)` shifted up 52, as puzzle_module.dart does.
- 2.2 mm in px: mirrorMinPieceMm 2.2 x phonePxPerMm (160/25.4) = 13.9 px.
- 956x440: strip fits both dims **8/18**; today's mirror is null **1/18** (train); fits where today is null **1** (train). Strip 58.6 px tall, 228.0 to 322.4 px wide.
- 667x375: strip fits both dims **2/18**; today's mirror is null **17/18**; fits where today is null **2** (sun, dinosaur). Strip 48.0 px tall, 124.0 to 202.6 px wide.
- Height is what fails. Width never binds: the narrowest strip is 124.0 px, the widest floor is 74.2 px.
- Select and Start overlap the board in **18/18** puzzles at both sizes, gap 0.0 px (see Questions 1).
- Self-check: see below. Test run: `flutter test test/mirror_strip_proof_test.dart` passed; `tools/mine.sh` ok.

## Table

Columns: id, tray right, board (left,top size), strip x-range / width / height, floor (w x h px), fits, today's mirror, select and start (rect, gap to board), overlap.

956x440 (game box 956.0x388.0), floor: mirrorMinPieceMm 2.2 mm = 13.9 px

```
house tray right 654.4 board 346.5,107.4 263.1x271.8 strip x 662.4..956.0 width 293.6 px = 46.6 mm, height 58.6 px = 9.3 mm floor 59.4x61.4 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
rocket tray right 677.9 board 380.4,90.3 195.2x287.9 strip x 685.9..956.0 width 270.1 px = 42.9 mm, height 58.6 px = 9.3 mm floor 46.2x68.1 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
tree tray right 625.6 board 344.9,110.3 266.3x270.1 strip x 633.6..956.0 width 322.4 px = 51.2 mm, height 58.6 px = 9.3 mm floor 60.6x61.5 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
sun tray right 677.1 board 344.8,167.6 266.3x211.2 strip x 685.1..956.0 width 270.9 px = 43.0 mm, height 58.6 px = 9.3 mm floor 55.2x43.8 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
fish tray right 708.5 board 330.4,128.5 295.1x249.3 strip x 716.5..956.0 width 239.5 px = 38.0 mm, height 58.6 px = 9.3 mm floor 57.4x48.5 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
snowman tray right 646.4 board 400.9,124.8 154.3x254.1 strip x 654.4..956.0 width 301.6 px = 47.9 mm, height 58.6 px = 9.3 mm floor 35.7x58.8 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
boat tray right 685.2 board 289.7,111.0 376.7x265.9 strip x 693.2..956.0 width 262.8 px = 41.7 mm, height 58.6 px = 9.3 mm floor 70.3x49.6 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
car tray right 711.7 board 304.2,114.1 347.6x262.1 strip x 719.7..956.0 width 236.3 px = 37.5 mm, height 58.6 px = 9.3 mm floor 68.1x51.4 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
robot tray right 658.2 board 370.0,120.3 215.9x259.1 strip x 666.2..956.0 width 289.8 px = 46.0 mm, height 58.6 px = 9.3 mm floor 49.5x59.4 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
train tray right 685.4 board 313.0,140.6 329.9x236.4 strip x 693.4..956.0 width 262.6 px = 41.7 mm, height 58.6 px = 9.3 mm floor 73.5x52.7 px fits true mirror null select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
castle tray right 655.1 board 321.0,109.9 314.0x269.1 strip x 663.1..956.0 width 292.9 px = 46.5 mm, height 58.6 px = 9.3 mm floor 72.4x62.1 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
butterfly tray right 710.7 board 306.1,107.9 343.9x269.0 strip x 718.7..956.0 width 237.3 px = 37.7 mm, height 58.6 px = 9.3 mm floor 74.2x58.1 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
dragon tray right 694.2 board 314.1,86.8 327.7x292.3 strip x 702.2..956.0 width 253.8 px = 40.3 mm, height 58.6 px = 9.3 mm floor 73.3x65.3 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
windmill tray right 661.7 board 341.1,89.2 273.9x290.5 strip x 669.7..956.0 width 286.3 px = 45.4 mm, height 58.6 px = 9.3 mm floor 57.8x61.4 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
lighthouse tray right 711.2 board 331.1,88.4 293.9x292.0 strip x 719.2..956.0 width 236.8 px = 37.6 mm, height 58.6 px = 9.3 mm floor 67.7x67.3 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
dinosaur tray right 679.1 board 288.1,116.7 379.9x260.5 strip x 687.1..956.0 width 268.9 px = 42.7 mm, height 58.6 px = 9.3 mm floor 69.3x47.5 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
tractor tray right 666.5 board 329.9,117.4 296.1x260.4 strip x 674.5..956.0 width 281.5 px = 44.7 mm, height 58.6 px = 9.3 mm floor 62.8x55.2 px fits true mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
tower tray right 720.0 board 388.6,87.5 178.8x292.9 strip x 728.0..956.0 width 228.0 px = 36.2 mm, height 58.6 px = 9.3 mm floor 38.1x62.4 px fits false mirror placed select 408.0,146.0 66.0x40.0 gap 0.0 start 482.0,146.0 66.0x40.0 gap 0.0 overlap true
956.0x440.0 totals: strip fits both dims 8 of 18; today mirror null 1 of 18; fits where today is null 1; select or start overlaps the board 18 of 18

667x375 (game box 667.0x323.0), floor: mirrorMinPieceMm 2.2 mm = 13.9 px
house tray right 480.3 board 224.0,89.4 219.0x226.3 strip x 488.3..667.0 width 178.7 px = 28.4 mm, height 48.0 px = 7.6 mm floor 59.4x61.4 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
rocket tray right 499.9 board 252.2,75.2 162.5x239.7 strip x 507.9..667.0 width 159.1 px = 25.3 mm, height 48.0 px = 7.6 mm floor 46.2x68.1 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
tree tray right 456.4 board 222.7,91.8 221.7x224.8 strip x 464.4..667.0 width 202.6 px = 32.2 mm, height 48.0 px = 7.6 mm floor 60.6x61.5 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
sun tray right 499.3 board 222.6,139.5 221.7x175.8 strip x 507.3..667.0 width 159.7 px = 25.4 mm, height 48.0 px = 7.6 mm floor 55.2x43.8 px fits true mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
fish tray right 525.4 board 210.7,107.0 245.7x207.6 strip x 533.4..667.0 width 133.6 px = 21.2 mm, height 48.0 px = 7.6 mm floor 57.4x48.5 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
snowman tray right 473.7 board 269.3,103.9 128.4x211.6 strip x 481.7..667.0 width 185.3 px = 29.4 mm, height 48.0 px = 7.6 mm floor 35.7x58.8 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
boat tray right 506.0 board 176.7,92.4 313.6x221.3 strip x 514.0..667.0 width 153.0 px = 24.3 mm, height 48.0 px = 7.6 mm floor 70.3x49.6 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
car tray right 528.1 board 188.8,95.0 289.3x218.2 strip x 536.1..667.0 width 130.9 px = 20.8 mm, height 48.0 px = 7.6 mm floor 68.1x51.4 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
robot tray right 483.5 board 243.6,100.1 179.7x215.7 strip x 491.5..667.0 width 175.5 px = 27.9 mm, height 48.0 px = 7.6 mm floor 49.5x59.4 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
train tray right 506.1 board 196.2,117.0 274.6x196.8 strip x 514.1..667.0 width 152.9 px = 24.3 mm, height 48.0 px = 7.6 mm floor 73.5x52.7 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
castle tray right 481.0 board 202.8,91.5 261.4x224.0 strip x 489.0..667.0 width 178.0 px = 28.3 mm, height 48.0 px = 7.6 mm floor 72.4x62.1 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
butterfly tray right 527.3 board 190.4,89.8 286.3x223.9 strip x 535.3..667.0 width 131.7 px = 20.9 mm, height 48.0 px = 7.6 mm floor 74.2x58.1 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
dragon tray right 513.4 board 197.1,72.3 272.8x243.3 strip x 521.4..667.0 width 145.6 px = 23.1 mm, height 48.0 px = 7.6 mm floor 73.3x65.3 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
windmill tray right 486.5 board 219.5,74.3 228.0x241.8 strip x 494.5..667.0 width 172.5 px = 27.4 mm, height 48.0 px = 7.6 mm floor 57.8x61.4 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
lighthouse tray right 527.6 board 211.2,73.6 244.6x243.0 strip x 535.6..667.0 width 131.4 px = 20.9 mm, height 48.0 px = 7.6 mm floor 67.7x67.3 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
dinosaur tray right 500.9 board 175.4,97.1 316.2x216.8 strip x 508.9..667.0 width 158.1 px = 25.1 mm, height 48.0 px = 7.6 mm floor 69.3x47.5 px fits true mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
tractor tray right 490.4 board 210.3,97.8 246.5x216.8 strip x 498.4..667.0 width 168.6 px = 26.8 mm, height 48.0 px = 7.6 mm floor 62.8x55.2 px fits false mirror null select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
tower tray right 535.0 board 259.1,72.8 148.8x243.8 strip x 543.0..667.0 width 124.0 px = 19.7 mm, height 48.0 px = 7.6 mm floor 38.1x62.4 px fits false mirror placed select 274.2,121.8 55.3x40.0 gap 0.0 start 337.5,121.8 55.3x40.0 gap 0.0 overlap true
667.0x375.0 totals: strip fits both dims 2 of 18; today mirror null 17 of 18; fits where today is null 2; select or start overlaps the board 18 of 18
```

## Self-check (review-rules part A)

1. Host setups: only the joined phone (`LayoutTarget.phones`, `PadMode.sticks`) at two sizes, table test per screen. TV or PC host, "Play on this phone", "Show on this device", peer one build older: not measured.
2. Kept state: none. The test holds no state; nothing to start or end.
3. Combination with pause menu, host away, player away, "Get ready", dropped link, results, leaving: not in scope; not measured.
4. Folder and allow: the new test file and this report only.
5. Stop: no spot built and no lib change; the owner decides from the numbers.
6. Looks: the phone sticks look at the two sizes only. The menu look and the TV look are not measured. No fixed pixel height is used for a look-sized widget; the strip height comes from the pad rects.

## Decisions

- Select and Start use `stickLayout(box)` on the game box, as the brief says (Question 1).
- Strip height: from 0 to the top of the highest right rect past the strip's left, less `mirrorGapPx`. If no right rect is past it, the code uses the box height.
- Imports added beyond the brief's list: `gyro.dart` and `joined_view.dart` (`PadMode`, `leftPadRects`, `rightPadRects` live there). Needed to compile.
- The one assert: every pad and right rect lies inside the game box (no numbers pinned).
- Copied the helpers from `mirror_proof_test.dart` (not edited).

## Hand-over

- `mine.sh` formatted the new test file (dart format), then passed on the second run.
- `flutter test` ran `pub get` for the workspace; no tracked file changed by me (the `M` entries in `git status` were already there at start).

## Questions

1. Select and Start overlap the board in 18/18 at both sizes, gap 0.0 px. The brief computes them with `stickLayout(game box)`, but the pad rects come from `leftPadRects(screen)` shifted up 52. If the on-screen Select sits at `stickLayout(screen)` shifted up 52 instead, these numbers change. Not measured both ways. Which body should the owner's answer use?
2. Height binds, not width: the strip is 58.6 px tall at 956x440 and 48.0 px at 667x375 (floors are 43.8 to 68.1 px tall at both sizes). The strip's height is set by the highest right-hand rect: its top is 66.6 px in the game box at 956x440 and 56.0 px at 667x375. Owner decides whether that rect is the lever.
3. The floor's height uses `board.height` times the floor scale, as the brief says. That matches the width rule; no other floor was used.

## Commit message

m165 c1: measure the mirror strip inside the game box, both sizes

Add mirror_strip_proof_test.dart, a measurement only: the game box is
the screen less the 52 px top bar, and the strip is measured there at
956x440 and 667x375 for all 18 puzzles. The strip fits both dims for
8/18 and 2/18; today's mirror is null for 1/18 and 17/18. Height is
what fails; width never binds. Select and Start overlap the board in
18/18 (gap 0). No lib change.

## Status row

B-042 c1: strip measured in the game box at both sizes (956x440: fits 8/18, today null 1/18; 667x375: fits 2/18, today null 17/18; height binds). Open: owner's spot decision, and whether Select/Start should use the screen or the game-box layout (overlap 18/18 as computed).

## Delete

- none
