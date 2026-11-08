job: M13 step 1b (G4) — the light stays at the screen's top-left when a shape turns, and the Windows TV app draws with Skia
stop: after it.
read: docs/briefs/m13/s1-spike-report.md (the "Claude's review" section at the end) · packages/toy_look/lib/src/toy_shape.dart · packages/toy_look/lib/src/body_fallback.dart · their tests · tv_test_app/windows/runner/main.cpp · docs/review-rules.md · docs/coding-guidelines.md

Claude's device check found two things (details at the end of the spike report):
- The light turns with the shape. Every game piece turns (Shape Race rotates pieces), so a highlight that ends up at the bottom looks wrong.
- On Windows, Flutter 3.47's default renderer (Impeller) draws 128 outlined, shadowed shapes in 71 ms a frame; Skia draws them in 4.8 ms on the same PC.

Claude's rules:
1. `toyShape` keeps the light at the screen's top-left whatever the canvas's rotation: read the rotation from `canvas.getTransform()` (the angle of the transformed x axis, `atan2(m[1], m[0])`), and turn the light the other way before using it. With the shader: `uLight` is `toyLight` turned by minus that angle. With the fallback: the gradient runs along the same turned direction (from the bounds' centre minus the light direction to plus it, as `Alignment`s), and the glint sits on the lit side (its 27%/24% position turned the same way about the bounds' centre). Put the turning in a small pure function (angle in, light direction or alignments out) and test it directly; `toyShape` itself stays the one call that draws.
2. A canvas that is only translated or scaled behaves exactly as now (angle 0). Mirrored transforms (negative scale) aren't used anywhere; say so in a doc comment rather than handling them.
3. `tv_test_app/windows/runner/main.cpp`: right after the `flutter::DartProject project(L"data");` line, add `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);` with a comment: the Windows TV app draws with Skia because Impeller on Windows (Flutter 3.47) was about 15 times slower at drawing many outlined shapes (M13 spike, Nov 8, 2026: 71 ms against 4.8 ms a frame for 128 shapes on an RTX 3080); re-check at every Flutter upgrade, and Flutter says the switch will be removed in a future release.
4. docs/project-notes.md: add one lesson under its fitting heading, two or three lines: Windows draws with Skia (why, the numbers, where the switch is, re-check on upgrade); and `flutter test` doesn't load fragment shaders (FragmentProgram.fromAsset fails: asset not found), so shader code is tested through its fallback and checked on a device.
5. Change nothing else.

tests (each failing first): the pure function for angles 0, 90°, 180° and 225° (the light's direction turns by minus the angle; at 0 it's exactly `toyLight`); the fallback's gradient alignments at 0 equal today's top-left to bottom-right; at 180° they're reversed (bottom-right to top-left) in the shape's own coordinates, i.e. still top-left on screen.

in the report: test counts before and after (look, tv); the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s1b-light-and-skia-report.md · packages/toy_look · tv_test_app/windows/runner/main.cpp · docs/project-notes.md
check: format analyze look tv
report: docs/briefs/m13/s1b-light-and-skia-report.md
