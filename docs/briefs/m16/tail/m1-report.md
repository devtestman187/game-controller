GATE: option A places the mirror for 16/18 at 956x440 and 1/18 at 667x375 (sticks); today 17/18 and 1/18; either spot 18/18 and 2/18

## Summary

- Changed: `controller_app/test/mirror_corner_proof_test.dart` (new file, measurement only; no lib change). Four tests: 956x440 and 667x375, each in sticks and dpad mode.
- Checks: `tools/mine.sh` OK (format, analyze with no findings, 4 tests). `flutter test test/mirror_corner_proof_test.dart` ran once: All 4 tests passed; the table below is its output.
- Decisions (none needed the driver):
  1. Option A rect = board size × s, anchored top-right, inset `PuzzleCamera.mirrorGapPx` from the box's top and right edges.
  2. Clear = inside the box; tray plain and board inflated by the gap both not overlapped; no pad rect overlapped; every right circle at least the gap away (centre-to-rect distance less radius).
  3. "Fits" = clear at the floor scale. The largest clear scale is found by 30 bisection steps between the floor and `world.scale * mirrorFraction`; `s/floor` is that largest scale over the floor scale.
  4. Right circles: sticks = `stickLayout(box).faceButtons` and `.rightStick` (not the floating zone); dpad = `padLayout(box).faceButtons`. Start is excluded.
  5. Whole-screen count: `leftPadRects(screen)` and `rightPadRects(screen)` used as the functions return them. `rightPadRects` already shifts by the bar, so its output is in screen px and includes Start.
- Self-check (review-rules part A):
  1. Host setups: not applicable, no lib change; the test covers the joined-phone pad layout at the two screens. Test: all four tests.
  2. Kept state: none; the test is pure, no clock or timer. Test: all four tests.
  3. Combination with the pause menu, host away, results, etc.: not applicable, no lib change.
  4. Stayed in allow: yes, only the new test file and this report.
  5. Stopped rather than overstepped: nothing stuck.
  6. Looks: no widget and no look-sized widget; the rects are measured in px at the two screens.

## Table (flutter test output, `Shell:` prefix removed)

956x440 sticks, game box 956.0x388.0 (floor 2.2 mm = 13.9 px)
```
house fits true s/floor 1.08 rect 883.8,8.0 64.2x66.3 today placed
rocket fits true s/floor 1.09 rect 897.5,8.0 50.5x74.5 today placed
tree fits true s/floor 1.07 rect 883.0,8.0 65.0x65.9 today placed
sun fits true s/floor 1.25 rect 879.1,8.0 68.9x54.7 today placed
fish fits true s/floor 1.27 rect 874.8,8.0 73.2x61.8 today placed
snowman fits true s/floor 1.12 rect 908.1,8.0 39.9x65.8 today placed
boat fits true s/floor 1.17 rect 865.7,8.0 82.3x58.1 today placed
car fits true s/floor 1.16 rect 869.2,8.0 78.8x59.4 today placed
robot fits true s/floor 1.13 rect 892.1,8.0 55.9x67.1 today placed
train fits true s/floor 1.11 rect 866.5,8.0 81.5x58.4 today null
castle fits true s/floor 1.00 rect 875.5,8.0 72.5x62.1 today placed
butterfly fits true s/floor 1.04 rect 871.1,8.0 76.9x60.2 today placed
dragon fits false s/floor none rect none today placed
windmill fits true s/floor 1.09 rect 884.9,8.0 63.1x66.9 today placed
lighthouse fits false s/floor none rect none today placed
dinosaur fits true s/floor 1.21 rect 864.1,8.0 83.9x57.5 today placed
tractor fits true s/floor 1.14 rect 876.7,8.0 71.3x62.7 today placed
tower fits true s/floor 1.21 rect 901.7,8.0 46.3x75.8 today placed
```
956x440 dpad, game box 956.0x388.0
```
house fits true s/floor 1.07 rect 884.3,8.0 63.7x65.9 today placed
rocket fits true s/floor 1.09 rect 897.5,8.0 50.5x74.5 today placed
tree fits true s/floor 1.06 rect 883.6,8.0 64.4x65.3 today placed
sun fits true s/floor 1.25 rect 879.1,8.0 68.9x54.7 today placed
fish fits true s/floor 1.23 rect 877.5,8.0 70.5x59.6 today placed
snowman fits true s/floor 1.12 rect 908.1,8.0 39.9x65.8 today placed
boat fits true s/floor 1.09 rect 871.2,8.0 76.8x54.2 today placed
car fits true s/floor 1.09 rect 873.5,8.0 74.5x56.2 today placed
robot fits true s/floor 1.13 rect 892.1,8.0 55.9x67.1 today placed
train fits true s/floor 1.04 rect 871.7,8.0 76.3x54.7 today placed
castle fits false s/floor none rect none today placed
butterfly fits false s/floor none rect none today placed
dragon fits false s/floor none rect none today placed
windmill fits true s/floor 1.09 rect 885.1,8.0 62.9x66.7 today placed
lighthouse fits false s/floor none rect none today placed
dinosaur fits true s/floor 1.12 rect 870.1,8.0 77.9x53.4 today placed
tractor fits true s/floor 1.10 rect 878.9,8.0 69.1x60.8 today placed
tower fits true s/floor 1.21 rect 901.7,8.0 46.3x75.8 today placed
```
667x375 sticks, game box 667.0x323.0
```
house fits false s/floor none rect none today null
rocket fits false s/floor none rect none today null
tree fits false s/floor none rect none today null
sun fits true s/floor 1.03 rect 602.3,8.0 56.7x45.0 today null
fish fits false s/floor none rect none today null
snowman fits false s/floor none rect none today null
boat fits false s/floor none rect none today null
car fits false s/floor none rect none today null
robot fits false s/floor none rect none today null
train fits false s/floor none rect none today null
castle fits false s/floor none rect none today null
butterfly fits false s/floor none rect none today null
dragon fits false s/floor none rect none today null
windmill fits false s/floor none rect none today null
lighthouse fits false s/floor none rect none today null
dinosaur fits false s/floor none rect none today null
tractor fits false s/floor none rect none today null
tower fits false s/floor none rect none today placed
```
667x375 dpad, game box 667.0x323.0
```
house fits false s/floor none rect none today null
rocket fits false s/floor none rect none today null
tree fits false s/floor none rect none today null
sun fits true s/floor 1.04 rect 601.6,8.0 57.4x45.5 today placed
fish fits true s/floor 1.04 rect 599.5,8.0 59.5x50.3 today null
snowman fits false s/floor none rect none today null
boat fits false s/floor none rect none today null
car fits false s/floor none rect none today null
robot fits false s/floor none rect none today null
train fits false s/floor none rect none today null
castle fits false s/floor none rect none today null
butterfly fits false s/floor none rect none today null
dragon fits false s/floor none rect none today null
windmill fits false s/floor none rect none today placed
lighthouse fits false s/floor none rect none today null
dinosaur fits false s/floor none rect none today null
tractor fits false s/floor none rect none today placed
tower fits true s/floor 1.01 rect 620.5,8.0 38.5x63.1 today null
```

## Totals (per screen and mode)

| screen, mode | A fits | today placed | today null | A fits where today null | either places | neither | whole-screen box today placed |
|---|---|---|---|---|---|---|---|
| 956x440 sticks | 16/18 | 17/18 | 1 | 1 | 18/18 | 0 | 14/18 |
| 956x440 dpad | 14/18 | 18/18 | 0 | 0 | 18/18 | 0 | 18/18 |
| 667x375 sticks | 1/18 | 1/18 | 17 | 1 | 2/18 | 16 | 3/18 |
| 667x375 dpad | 3/18 | 3/18 | 15 | 2 | 5/18 | 13 | 2/18 |

Option A misses dragon and lighthouse at 956x440 sticks; today places both, and "either" covers them. Only the wide screen gives option A a spot for most puzzles.

## Matching m165 REPORT.md (I matched by the numbers in the brief; I did not open that file)

- REPORT.md:75 (placed 14/18, 3/18) matches the whole-screen box column (14/18 at 956x440 sticks, 3/18 at 667x375 sticks). That count uses the whole screen as the box with unshifted rects, as b3 did.
- REPORT.md:106 (null 1/18, 17/18) matches the game-box null counts (1 at 956x440 sticks, 17 at 667x375 sticks). That count uses the game box with rects shifted up by the bar.
- The two are different setups, so both are right for the box each one used.

## Questions and suggestions

1. Is the whole-screen box meant to take the rects as the functions return them (my choice, including Start), or with Start removed?
2. At 667x375, option A is clear for 1 puzzle (sticks) and 3 (dpad). The driver should decide whether that screen needs a different spot.
3. Suggest the driver reads "either" (18/18 and 2/18) as the measure for the next job, since that is the best the two spots reach together.

## Commit message — a draft

test: measure the mirror corner beside the button ring (m16 tail m1)

Adds a measurement-only test for B-042: option A (the top-right corner over the
empty corner of the button ring, ignoring touches) on 956x440 and 667x375, sticks
and dpad, all 18 puzzles. No lib change. Prints one line per puzzle and totals,
including today's mirrorPlace in the game box and the whole-screen box.
Results: A fits 16/18 and 1/18 (sticks); today places 17/18 and 1/18; either spot 18/18 and 2/18.

## Status row

m16 tail m1: corner measured on 18 puzzles at 2 screens and 2 pad modes (test only, no lib change). Option A places 16/18 at 956x440 sticks (today 17/18, either 18/18) and 1/18 at 667x375 sticks (today 1/18, either 2/18). Open: the driver's choice of spot for 667x375, and whether to build option A.

## Delete

- none
