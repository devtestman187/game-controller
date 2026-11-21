# M16 phonehost2 S9t — the TV check at 1920x1080: the focus ring's device px, the home in the frame

## Summary

- NEW `tv_test_app/test/tv_focus_ring_frame_test.dart`, 4 tests, all pass: the ring's thickness round a
  focused home button (`openPlay`) in a screenshot at 1920x1080, 1280x720 and 1024x768, and the home at
  1920x1080 (frame, text floor, no overflow). Tests-first is exempt (brief): the code exists.
- The ring scales with the frame, as the owner decided. Measured across the button's left edge, device px:

  | device    | s                | 4 frame px * s | measured band | of it solid #FFD23F |
  | --------- | ---------------- | -------------- | ------------- | ------------------- |
  | 1920x1080 | 2                | 8.00           | 8             | 6                   |
  | 1280x720  | 1280/960=1.33333 | 5.33           | 5             | 3                   |
  | 1024x768  | 1024/960=1.06667 | 4.27           | 5             | 3                   |

- What the band is (toy_button.dart:340): the focus colour fills a pill inflated by
  `outlineWidth/2 + ToySizes.focusRing`, then a 1.5 frame px ink stroke is drawn centred on that path.
  At the TV's outline of 4 the pill's ink covers 2 of the 4 px and the ring's own ink 0.75, so the
  **solid focus colour is 3.25 frame px** (6.5 device px at s = 2 with the bounce), not 8. The test
  measures the pixels between the two ink edges, blends included: the 4 frame px the design names.
- The 1.04 focus bounce is a transform inside the button, so a focused button paints outside its layout
  box (5 device px at the TV); the scan starts at the button's middle, which the bounce cannot move.
- Home at 1920x1080: frame 960x540, s 2, `HomeScreen` 960x540 frame px, dpr 1 (screenshot-free); no
  overflow (`takeException` null); 49 texts, smallest 22 frame px = 44 device px (floor 20 frame px);
  21 texts outside the panels' scroll views, all on screen; 28 inside them.
- Numbers that look wrong but are not: two controller lines are ellipsized by design
  (`controllers_panel.dart:167`, 200 frame px box, the same at 960x540 before the frame), and the
  scrolling panels' content runs past the frame (pairing panel to 1091 frame px; its last visible
  line's bottom 5 frame px cut at the frame's foot by its viewport, not an overflow).

## Files changed

- `tv_test_app/test/tv_focus_ring_frame_test.dart` (new) — the 3 ring tests and the 1920x1080 home test;
  local copies of the pixels helper's idea, `_ringBand` (the measurement), `_deviceRect`, `_inScrollView`.
- `docs/briefs/m16/phonehost2/s9t-report.md` (new) — this report.

## Computed values the tests assert

- Ring at 1920x1080: s = min(1920/960, 1080/540) = 2; expected 4 * 2 = 8 device px; measured band 8
  (pixels 1227..1234 of the row through the button's middle: 1227 `#B49341` and 1234 `#382C45` the
  blends, 1228..1233 solid `#FFD23F`).
- Ring at 1280x720: s = 1280/960 = 1.3333333333333333; expected 5.333333333333333; measured 5 (818
  `#C19E41`, 819..821 solid, 822 `#CEA941`).
- Ring at 1024x768: s = 1024/960 = 1.0666666666666667; expected 4.266666666666667; measured 5 (654
  `#755F43`, 655..657 solid, 658 `#4F3F44`).
- Focus colour `#FFD23F`, ink `#1E1646` (the look's `colors.focus`/`colors.ink`, both palettes use the
  same focus). Each test also asserts the band contains the focus colour exactly.
- Home at 1920x1080: frame 960 x 540 frame px (±1e-9), scale 2, `tester.getSize(HomeScreen)` 960x540,
  `devicePixelRatio` 1, smallest text 22 frame px → 44 device px ≥ 40.

## How the measurement works (and what it is not)

- Screenshot: the root layer's `toImage` of the whole 1920x1080 screen inside `tester.runAsync` (the
  party_host pixels helper's way, copied because it lives under that package's `test/`). One bitmap
  pixel per device logical pixel, as the harness sets dpr 1.
- A `RepaintBoundary` around the button was tried first and abandoned: the ring is painted outside the
  button's layout box by the bounce, so a boundary at the box clips exactly what is to be measured.
- The scan is one horizontal row at the box's middle, where a stadium's left edge is vertical, so the
  width across it is the band's thickness. Colours are compared by the largest channel gap; the run is
  the pixels nearer the focus colour than the ink; then it grows over the boundary pixels until solid
  ink on both sides. The scan window reaches 24 device px past the layout box for the bounce.
- With a stricter definition (only pixels nearer the focus colour than the ink) the run is 7 / 5 / 3,
  which fails 4.27 +- 1 at the tablet; with only solid-colour pixels it is 6 / 3 / 3. All three are in
  the report so the reviewer can pick the definition: the test asserts the edge-to-edge band, which is
  the one that carries the design's 4 px meaning.

## Self-check (review-rules part A)

1. **Every host setup** — the test mounts the TV app only; the frame and the focus look are the shared
   widgets, so a phone host draws the same band scaled by its own s and no host-specific branch exists
   here. The phone app's host mode is outside this job (S2's gate), so it is not tested:
   `the focus ring is ... at 1920x1080/1280x720/1024x768`.
2. **When kept state starts and ends** — nothing is held: one screenshot per pump, no timers, no caches;
   the focus bounce is the only animation and `_focusButton` pumps it to its 1.04 rest before the read
   (`the focus ring is ...`).
3. **How a new state combines** — no state is added; the test requests the focus the way the remote does
   and reads what the existing focus look paints, with no pause/away/round state involved
   (`the home at 1920x1080 ...` and the three ring tests).
4. **Stay in the job's folder** — `git status --short` shows the two files in `allow:` and nothing else
   of mine: `run.log` (3 lines, the runner's log), and `tv_test_app/windows/flutter/generated_plugin*`
   modified with an empty diff (line endings only, as s1 reported); nothing else was written.
5. **Stop rather than overstep** — no lib change; the brief's 8 device px at s = 2 is only true with the
   ring's ink edge counted with the yellow, so the test says what it measures and this report names the
   difference; nothing was changed to make the number fit.

## Hand-over

- S9t is the measurement only: the TV home at 1920x1080 is in the frame, nothing overflows, the smallest
  text is 22 frame px (44 device), and the ring scales with the frame (band 8 / 5 / 5 device px at s
  2 / 1.33 / 1.07).
- Open for the main session: (1) DESIGN line 71 ("the focus ring size ... unaffected") still needs the
  reword; if it is reworded, say "the ring's band, ink edge to ink edge" rather than "4 frame px", since
  the solid focus colour is 3.25 frame px because of the ring's own ink stroke; (2) if the test's
  definition is not the one wanted, the other two counts are in this report (7/5/3 strict, 6/3/3 solid);
  (3) the two ellipsized controller address lines are pre-existing and could get more room if wanted.
- Not run: the phone app's host screens (out of scope), the Windows/desktop build, and any real-device
  look. No screenshot is committed.

## Commit message

```
Test the TV focus ring's device px at three sizes

The ring's band round a focused home button is measured in a screenshot
of the framed TV app: 8 device px at 1920x1080 (s 2), 5 at 1280x720 and
5 at 1024x768, against 4 frame px times s. The shared test counts the
pixels between the ring's ink edges, so it also shows that the solid
focus colour is 3.25 frame px (6.5 device px at s 2): the ring's 1.5 px
ink stroke is drawn centred on its path. The same file checks the home
at 1920x1080: 960x540 frame px at scale 2, no overflow, smallest text
22 frame px = 44 device px. No lib change.
```

## Status row

S9t done: `tv_test_app/test/tv_focus_ring_frame_test.dart` measures the TV focus ring (band 8 / 5 / 5 device px at s 2 / 1.33 / 1.07) and the framed home at 1920x1080 (960x540 frame px, no overflow, smallest text 44 device px); open — the solid focus colour is 3.25 frame px not 4, DESIGN line 71's reword, and the rest of S9.

## Delete

- none
