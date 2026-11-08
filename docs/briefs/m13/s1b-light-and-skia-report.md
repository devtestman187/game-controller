# M13 step 1b: the light stays at the screen's top-left, and Windows draws with Skia (G4 report)

Job: `docs/briefs/m13/s1b-light-and-skia.md`. Gate: G4, the whole step. Rules 1–5 are in;
nothing outside this job's allow list was touched, and no other file was changed.

## What changed

**The light no longer turns with the shape (rule 1).**

- `packages/toy_look/lib/src/turn.dart` (new, 19 lines, internal like `body_fallback.dart`):
  `toyTurnBack(offset, angleRad)` is the one pure turning: `(x cos a + y sin a, y cos a − x sin a)`,
  i.e. it turns by **minus** the angle, so a screen direction becomes the shape's own.
- `toy_shape.dart`:
  - `toyLightIn(angleRad)` — "angle in, light direction out": `toyTurnBack(toyLight, angleRad)`.
    At 0 it is exactly `toyLight`. A doc comment on `toyShape` says the light stays at the
    screen's top-left, that a canvas which only translates or scales has angle 0 and draws as
    before, and that mirrored transforms (a negative scale) aren't used by any game and aren't
    handled (rule 2).
  - `_canvasTurnRad(canvas)` — `atan2(m[1], m[0])` of `canvas.getTransform()`: the angle of the
    transformed x axis, so a translation or a positive scale adds nothing.
  - `toyShape` reads the angle once per draw and passes it to the body (shader or fallback); the
    shader's `uLight` is `toyLightIn(turnRad)`. `toyShape` is still the one call that draws.
- `body_fallback.dart`:
  - `toyGradientAxis(angleRad)` — "angle in, alignments out": the screen's top-left →
    bottom-right diagonal turned back by the canvas's angle, as `begin`/`end` `Alignment`s.
    At 0 they are exactly `Alignment.topLeft`/`Alignment.bottomRight`; the ends stay a bounds'
    diagonal apart at every angle, so the bands cross the shape the same way.
  - `toyGlintBounds(bounds, angleRad)` — the glint's 27%/24% place, as an offset from the bounds'
    centre, turned back by the same angle, so it stays on the screen's lit side.
  - `paintFallbackBody` takes the angle and passes it to both. `toyBodyGradient` takes the angle
    and uses `toyGradientAxis`.
  - Small cleanup in a line I had to change anyway: `toyBodyGradient` lost its `Rect bounds`
    parameter, which it never used (guideline §2, leftovers: unused parameters). Its only caller
    still handed it the same `bounds` for `createShader`.

**Windows draws with Skia (rule 3).** `tv_test_app/windows/runner/main.cpp`: right after
`flutter::DartProject project(L"data");`, `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);`
with the comment the brief asked for (the 15× numbers, the M13 spike date and PC, re-check at
every Flutter upgrade, the switch goes in a future release).

**`docs/project-notes.md` (rule 4).** Two bullets: **Windows draws with Skia** under *Lessons
learned → Platforms*, and **`flutter test` doesn't load fragment shaders** under *Lessons learned →
Flutter and Dart*. The brief said "one lesson"; the two facts have different fitting headings
(one is a platform behaviour, one is a test-tool behaviour), so they are two bullets of two to
three lines each — say if they should be one.

## Tests (each failing first)

Both new tests were run against a stub `toyTurnBack` that returned its offset unchanged — the bug
itself, the light turning with the shape. `tools/check.sh look` then failed with:

```
look (10 passed, exit 1): the gradient runs from the screen's top-left whatever the canvas's turn
  Expected: a numeric value within <1e-9> of <1>  Actual: <-1.0>
look (10 passed, exit 1): the light turns back by the canvas's angle, so it stays at the screen's top-left
  Expected: a numeric value within <1e-9> of <-0.65>  Actual: <-0.55>
```

Both pass with the turning in (`look`, 12 tests).

**Computed values** (`toyLight` is (−0.55, −0.65); turning by minus the angle is
`(x cos a + y sin a, y cos a − x sin a)`):

| Angle | Expected light (what the test asserts) | Working |
| --- | --- | --- |
| 0 | exactly `toyLight` = (−0.55, −0.65) | `cos 0 = 1`, `sin 0 = 0`, so the values are untouched |
| 90° | (−0.65, 0.55) | x' = −0.55·0 + (−0.65)·1 = −0.65; y' = (−0.65)·0 − (−0.55)·1 = 0.55 |
| 180° | (0.55, 0.65) | both components negated |
| 225° | (0.848528, 0.070711) | cos 225 = sin 225 = −0.70710678: x' = 0.70710678·(0.55 + 0.65) = 0.848528; y' = 0.70710678·(0.65 − 0.55) = 0.070711 |

Both turned lights keep the light's length: √(0.55² + 0.65²) = 0.851469; √(0.848528² + 0.070711²)
= 0.851469.

**Fallback alignments** (`d` = (1, 1) turned back; `begin` = −d, `end` = d):

| Angle | begin | end | On screen |
| --- | --- | --- | --- |
| 0 | (−1, −1) = `Alignment.topLeft` | (1, 1) = `Alignment.bottomRight` | unchanged from today |
| 180° | (1, 1) = `Alignment.bottomRight` | (−1, −1) = `Alignment.topLeft` | the same corners, because the shape faces the other way |

The 180° case is compared with `closeTo(…, 1e-9)`: `sin(pi)` is 1.2246e-16, not 0, so the ends
are not exactly `Alignment.bottomRight`/`topLeft`. At 0 they are compared exactly (`sin 0` is 0).

The four existing drawing tests (shadow, outline, three bands, own colour) and the three existing
fallback tests (bands, glint place, glint turn) are unchanged in what they expect and still pass:
at angle 0 the drawing is pixel-for-pixel what it was.

## Test counts

| Check | Before | After |
| --- | --- | --- |
| `look` | 10 passed | 12 passed (+2) |
| `tv` | 32 passed, 1 skipped | 32 passed, 1 skipped (no tv Dart code changed) |

`tools/check.sh` prints no count for `tv` because of its one skipped test; the number above is
from `tools/check.sh --verbose tv` (`+32 ~1: All tests passed!`).

## Files changed

| File | Change |
| --- | --- |
| `packages/toy_look/lib/src/turn.dart` | **new**: `toyTurnBack`, the one pure turning |
| `packages/toy_look/lib/src/toy_shape.dart` | `toyLightIn`, `_canvasTurnRad`, `toyShape` passes the angle, `uLight` turned back; doc on mirrored transforms |
| `packages/toy_look/lib/src/body_fallback.dart` | `toyGradientAxis`, glint place turned about the centre, angle threaded through the gradient and `paintFallbackBody`; `bounds` dropped from `toyBodyGradient` |
| `packages/toy_look/test/toy_shape_test.dart` | new light test (0°, 90°, 180°, 225°) |
| `packages/toy_look/test/body_fallback_test.dart` | new alignments test (0°, 180°); existing calls pass the angle 0 |
| `tv_test_app/windows/runner/main.cpp` | `set_impeller_switch(Disabled)` with its comment |
| `docs/project-notes.md` | two lessons: Windows/Skia, fragment shaders under `flutter test` |

`git status` also lists `tv_test_app/windows/flutter/generated_plugin*` and
`generated_plugins.cmake` as modified; their timestamps predate this job (they were there before
the spike job too) and `git diff` on them is line endings only — not touched here.

No `lib` file is over 400 lines (`toy_shape.dart` 139, `body_fallback.dart` 127, `turn.dart` 19)
and no function is over 40 lines.

## Self-check (review-rules.md part A)

1. **Every host setup.** No message, capability, screen or stored state changed; the diff is the
   painter in `toy_look` and one Windows-only line in the runner. TV/PC host: draws exactly as
   before at angle 0 — the four existing `toyShape` drawing tests and the three fallback tests
   pass unchanged. Phone host ("Play on this phone", "Show on this device"), joined phone, one
   build older: not affected (no shared code path changed, no protocol change). Tests: `look`
   (12) and `tv` (32 + 1 skipped), both green.
2. **When kept state starts and ends.** Nothing is held, timed, counted or remembered: the angle
   is computed per `toyShape` call from that canvas and passed down as an argument; there is no
   new field, cache, global or listener. Tests: all 12 `look` tests, each of which draws through
   `toyShape`/`paintFallbackBody` with no setup or teardown.
3. **How a new state combines with the others.** No new state and nothing that pauses, hides or
   blocks input, so there is no pair with the pause menu, host away, player away, Get ready,
   results or leaving. The one caller that draws every frame, the TV spike screen, still runs:
   `tv` green, including "the Look test button opens the spike" and "Back leaves the spike
   screen".
4. **Stay in the job's folder.** Only allow-listed files were written (table above): `git status`
   shows the six modified files plus the new `turn.dart`; the three `windows/flutter/generated_*`
   entries predate the job.
5. **Stop rather than overstep.** Nothing outside the allow list was needed. What this job could
   not do here is stated below rather than worked around: the C++ was not compiled and no device
   was run.

## Checks run

- `tools/check.sh format analyze look tv`: **PASS** format (2 s), **PASS** analyze (9 s), **PASS**
  look (12 tests, 4 s), **PASS** tv (9 s) — "All checks passed (24 s)". (The first run failed
  format on `body_fallback_test.dart`; `dart format` on that file fixed it, then the run above.)
- `tools/review.sh`: **0 fail, 0 note**.

## Not sure about

1. **The C++ was not compiled.** No `flutter build`/`run` is in this job's `check:` line and
   starting a build is refused here, so `set_impeller_switch(flutter::ImpellerSwitch::Disabled)`
   has only been written as the brief gives it; the Windows runner headers were not inspected.
   The proof is the next Windows build, then the Look test screen at `Stress: on` (Skia should read
   about 5 ms a frame where Impeller read 71 ms).
2. **The canvas→angle wiring has no test of its own.** The brief listed two tests, both on the pure
   functions; `_canvasTurnRad` (`atan2` of the transform's first column) is covered only by the
   device check. A drawing test — rotate the canvas 180°, expect the highlight in the screen's
   top-left corner — would catch a wrong matrix index. I didn't add one because the brief named
   these two tests only.
3. **The glint's own −30° tilt still turns with the shape.** The brief asked for the glint's
   *place* to be turned back, not its tilt, so at 180° its oval is drawn at 150° on screen. If the
   tilt should stay as the screen shows it, the fix is one more term in the `canvas.rotate` call.
4. **The shadow still turns with the shape** (the shadow offset is applied in the canvas's own
   coordinates). The brief says nothing about it: at 180° the shadow falls up and to the left on
   screen while the light stays top-left. Say if the shadow should follow the screen too.
5. **"One lesson" written as two bullets** in project-notes (see above) because the facts fit two
   headings.

## Suggestions

1. When the look lands in Shape Race's pieces (next steps), measure `Stress: on` on the TV once
   per Flutter upgrade together with the Skia re-check, so the numbers in the note stay current.
2. A rotated drawing test (not sure about #2) would be cheap insurance the next time the painter
   changes.

## Commit message

Keep the light at the screen's top-left and draw the TV app with Skia

toyShape reads the canvas's angle from its transform and turns the light
back by it: the shader's uLight becomes toyLightIn(angle), and the
fallback's gradient and glint are turned the same way about the shape's
bounds, so a turning piece keeps its highlight at the screen's top-left
(M13 spike: a piece at 225° had it at the bottom). The turning is one
pure function, toyTurnBack, with its own tests at 0°, 90°, 180° and 225°.
The Windows runner turns Impeller off: on Flutter 3.47 it drew 128
outlined, shadowed shapes in 71 ms a frame against Skia's 4.8 ms.

## Status row

M13 step 1b: the light stays at the screen's top-left for the shader and the Canvas fallback (2 new look tests, 12 green) and the Windows TV app starts with Impeller disabled (Skia) — done; open: the Windows build and device check of both (Look test screen at Stress: on, ~4.8 ms expected), the shadow's direction and the glint's tilt under rotation (questions 3 and 4), the shading on the phone and iPhone targets.

## Delete

- none

## Claude's review (Nov 8)

Accepted. toyTurnBack is the right inverse rotation (local = R(-angle) · screen), and toyLightIn(0) is exactly toyLight. One gap fixed by Claude: the shadow's offset was still applied in the shape's own coordinates, so a piece at 180° cast its shadow up and to the left; it now goes through toyTurnBack too, with the test "a turned shape still casts its shadow down and to the right on screen" (failed first). look: 13 tests.
