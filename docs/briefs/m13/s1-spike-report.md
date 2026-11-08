# M13 step 1: the `toy_look` package and the shader spike screen (G4 report)

Job: `docs/briefs/m13/s1-spike.md`. Gate: G4, the whole step. Everything in the brief's
rules 1–6 and its test list is in; nothing outside the allow list was touched.

## What was built

- **`packages/toy_look`** (new): set up like `game_kit` (workspace resolution, sdk
  `^3.13.0`, flutter `>=3.38.0`, `flutter_lints`, `flutter_test`), added to the root
  `pubspec.yaml`'s `workspace:` list, and its `shaders/toy_shade.frag` declared under
  `flutter: shaders:` (so it ships as the asset `packages/toy_look/shaders/toy_shade.frag`).
  `lib/toy_look.dart` exports `src/toy_shape.dart` and `src/toy_shaders.dart`;
  `src/body_fallback.dart` stays internal (the tests import it by path).
- **`ToyShaders`** (`lib/src/toy_shaders.dart`): `load()` times
  `FragmentProgram.fromAsset` (`loadMs`), never throws — any failure comes back as
  `shade == null` plus `error` — and `ToyShaders.none` is the effects-off state. The asset
  key is a named parameter (`load({String asset = shadeAsset})`) so a test can ask for a
  key that isn't there.
- **`toyShape`** (`lib/src/toy_shape.dart`): shadow (path shifted by `shadowOffset`, ink at
  `shadowAlpha`), then the body (the shader, or the Canvas fallback), then the ink outline
  (round joins and caps). `ToyShapeStyle` holds `ink`, `outlineWidth`, `shadowOffset`,
  `shadowAlpha` with the brief's defaults; each default is a named const (`toyInk` 3 px,
  `Offset(2.25, 3)`, 0.35) with its design-section reason.
- The fallback (`lib/src/body_fallback.dart`): a `LinearGradient` top-left → bottom-right
  with hard stops 0–0.30 highlight, 0.30–0.75 the colour, 0.75–1 shade, plus the white
  glint (27% across, 24% down, 8% × 5%, turned −30°, 75% opaque).
- **`ShaderSpikeScreen`** (`tv_test_app/lib/src/ui/shader_spike_screen.dart`, with the
  shapes and painter in `shader_spike_rows.dart`): loads `ToyShaders` when opened, shows
  `Shader: on (loaded in N ms)` or `Shader: off: <error>` (and `Shader: loading…` until the
  load answers), two labelled shape rows (four shapes — circle, rounded square, triangle,
  wide bar — in four player colours) turning one turn per 8 s, a `Stress: off/on` button
  that adds 60 shapes to each row in all six player colours, and the average and worst of
  the last 120 frames' build plus raster time from `SchedulerBinding.addTimingsCallback`.
  Sunny background `0xFF7CC8F8`, plain Material labels and buttons, Back (Esc) leaves.
- **"Look test"** button on the TV home, next to Latency, same `HostButton` style and
  `_open` route as the others.
- **`tools/check.sh`**: `look|packages/toy_look|flutter test|the look package: shapes,
  shaders and fallback`, listed after `kit`; the `Checks:` header line now names it.

## Files changed

| File | Change |
| --- | --- |
| `packages/toy_look/pubspec.yaml` | new package: workspace resolution, flutter, lints, `flutter: shaders:` |
| `packages/toy_look/lib/toy_look.dart` | the library: exports the two source files |
| `packages/toy_look/lib/src/toy_shaders.dart` | `ToyShaders.load()` / `.none`, `loadMs`, `error` |
| `packages/toy_look/lib/src/toy_shape.dart` | `toyShape`, `ToyShapeStyle` and the style constants |
| `packages/toy_look/lib/src/body_fallback.dart` | the hard-stop gradient and the glint (internal) |
| `packages/toy_look/test/toy_shape_test.dart` | the drawing tests (shadow, outline, bands, own colour) |
| `packages/toy_look/test/body_fallback_test.dart` | the gradient, glint position/size and glint turn tests |
| `packages/toy_look/test/toy_shaders_test.dart` | missing asset, `none`, and the real key's contract |
| `packages/toy_look/test/support/pixels.dart` | paints into a `PictureRecorder` and reads pixels back |
| `tv_test_app/lib/src/ui/shader_spike_screen.dart` | the spike screen (200 lines) |
| `tv_test_app/lib/src/ui/shader_spike_rows.dart` | the four shape paths and the row painter (127 lines) |
| `tv_test_app/lib/src/ui/home/home_screen.dart` | the Look test button; the compact-width comment says five |
| `tv_test_app/test/shader_spike_screen_test.dart` | the screen's four tests |
| `tv_test_app/test/home_screen_test.dart` | the remote test now also presses Look test and opens the screen |
| `tv_test_app/pubspec.yaml` | `toy_look` path dependency |
| `pubspec.yaml` | `packages/toy_look` in `workspace:` |
| `tools/check.sh` | the `look` check |
| `pubspec.lock` | unchanged: workspace members aren't listed in it |

`git status` also shows `tv_test_app/windows/flutter/generated_plugin*` and
`generated_plugins.cmake` as modified; their timestamps are 10:52:25 (the worktree's own
`flutter pub get`, before this job's first command) and `git diff` on them is empty — line
endings only, no content.

## Tests

| Check | Before | After |
| --- | --- | --- |
| `tv` | 28 passed, 1 skipped | 32 passed, 1 skipped |
| `look` | — (no check) | 10 passed |

`check.sh` prints no count for `tv` because of that skipped test (its regex wants
`+N: All tests passed`, the reporter writes `+N ~1: All tests passed!`); the counts above
are from `flutter test` in each folder.

New `look` tests (each failed first for its own reason: the first run compiled
`toyShape` wrongly and the gradient test compared 8-bit constants against floating-point
`Color.lerp` results):

- `the fallback body is a hard-stop gradient from its highlight to its shade`: stops
  `[0, 0.30, 0.30, 0.75, 0.75, 1]`, colours (as ARGB32) `0xFF7DC1F6, 0xFF7DC1F6,
  0xFF2E9BF0, 0xFF2E9BF0, 0xFF2273B2, 0xFF2273B2`. Blue is (46, 155, 240); 38% to white is
  (46 + 79.4, 155 + 38, 240 + 5.7) = (125, 193, 246); 26% to black is (34.0, 114.7, 177.6).
- `the glint sits at 27% across and 24% down the bounds, 8% by 5% of them`: for
  `Rect.fromLTWH(100, 200, 200, 100)` the centre is (100 + 54, 200 + 24) = (154, 224) and
  the oval 200 × 0.08 = 16 by 100 × 0.05 = 5.
- `the glint is turned -30 degrees, so it leans up to the right`: on a 400 × 400 square the
  glint's centre is (108, 96) and its oval 32 × 20; the pixel at (116, 85) is (8.5, −10.5)
  from the centre, which turned −30° is (12.61, −4.84) in the oval's own axes —
  (12.61/16)² + (4.84/10)² = 0.855, inside — while an unturned oval would have
  (8.5/16)² + (10.5/10)² = 1.384, outside. The dark body there is (103, 113, 133), the
  glint over it (217, 220, 225); the test asserts red > 165.
- `toyShape draws the shadow under the shape, down and to the right of it`: ink (30, 22, 70)
  at 35% over white is (30 × 0.35 + 165.75, 22 × 0.35 + 165.75, 70 × 0.35 + 165.75) =
  (176.25, 173.45, 190.25), checked within ±2 at (40, 62) — the band the shadow shows below
  the 3 px outline (outline outer edge y 61.5, shadow bottom y 63) — and white at (16, 16).
- `toyShape strokes the ink outline over the body's edge`: (20, 40) is (30, 22, 70); the
  stroke spans x 18.5 to 21.5.
- `toyShape fills the body with the fallback's three bands, top-left to bottom-right`: the
  share along the 20,20 → 60,60 diagonal is ((x−20) + (y−20)) / 80, so (25, 25) is 0.125 →
  (125, 193, 246), (40, 40) is 0.5 → (46, 155, 240), (55, 55) is 0.875 → (34, 115, 178).
- `toyShape keeps each shape's own colour in one frame`: (46, 155, 240) in the first square
  and (255, 138, 31) in the second, drawn in one frame.
- `a shader that is not there leaves no shade and says why, and never throws`: a key that
  isn't in the bundle gives `shade == null` and a non-empty `error`.
- `none is the effects-off state: no shader and nothing to report`.
- `the package shader either loads or says why it did not`: `shade == null` iff `error !=
  null`, and `loadMs >= 0` — the contract, whatever the host can do.

New `tv` tests: the Look test button opens the spike and a Shader line is shown; both rows
are labelled and the turn advances a quarter of a turn in 2 s of 8 s (0.25 ± 0.05) with both
rows at the same turn; Stress adds 60 shapes to each row and the label flips to `Stress: on`;
Back leaves the screen. The home's remote test now also presses Look test and expects
`ShaderSpikeScreen` among the screens opened.

## `FragmentProgram.fromAsset` inside `flutter test`

It doesn't work, and it fails cleanly:
`Exception: Asset 'packages/toy_look/shaders/toy_shade.frag' not found`. `flutter test` doesn't
run the shader compiler (impellerc) and its asset bundle carries no `shaders/` entries, so in
the tests `ToyShaders.load()` always answers "off" — which is exactly the fallback path, and
why the test asserts the contract rather than a loaded program. Nothing in the tests depends
on a working shader; the two rows draw the fallback and look identical under `flutter test`.

**The shader's own compile was not checked in this job.** No `flutter build`/`run` is in the
job's `check:` line and starting a build was refused here, so `toy_shade.frag` has only been
read against the documented GLSL subset (research report §1: `460 core`, `FlutterFragCoord()`,
premultiplied `fragColor`, no sampler, no early return, no UBO). It is unchanged. The first
real build is the proof; the spike screen shows the result in its Shader line. If it fails to
compile, the error comes from the build, not from Dart.

## The brief's two questions

**Name-API uniforms (rule 2).** The name API is there in this SDK: `FragmentShader`'s
`getUniformVec2`, `getUniformVec4` (and `getUniformFloat`) compile against Flutter 3.47.x, and
`dart analyze --fatal-infos` is clean, so `toyShape` sets `uOrigin`, `uSize`, `uColor` and
`uLight` by name and no index fallback is needed. Not verified at runtime here, because no
program can load under `flutter test`; the spike screen on a real build is where it shows.

**Reusing one `FragmentShader` (rule 3).** One is made per draw
(`program.fragmentShader()` inside `toyShape`), not one per frame. A `FragmentShader` holds
its uniforms until changed, and the docs (research §1, §5) say two uniform sets alive at once
need two `fragmentShader()` calls; with one shader per frame the second shape would inherit the
first one's colour unless sets and draws are strictly interleaved, and the cost then depends
on the renderer's copy-on-draw behaviour, which can't be tested here. Each shape therefore
keeps its own colour (test: `toyShape keeps each shape's own colour in one frame`, which covers
the fallback; the shader path needs a device). The price is one small allocation per shape per
frame — see the suggestions.

## Self-check (review-rules.md part A)

1. **Every host setup.** TV/PC host: the screen is reachable from the TV home and opens
   locally — `shader_spike_screen_test` "the Look test button opens the spike…" and the home
   remote test. Phone "Play on this phone", "Show on this device", a joined phone and a
   one-build-older peer: not affected — the change adds no message, no capability and no
   shared screen, and only `tv_test_app` (+ the new package) changed.
2. **When kept state starts and ends.** The `AnimationController` starts in `initState`,
   repeats until `dispose`; the timings callback is added in `initState` and removed in
   `dispose`; the shader load checks `mounted` before `setState`; the 120-frame window starts
   empty and ends with the screen. Nothing else is held: no round, no players, no app-wide
   state. Test: "Back leaves the spike screen" (and every widget test would fail on a ticker
   left running).
3. **How a new state combines with the others.** The screen's only states are one bool
   (`_stress`) and the nullable `ToyShaders`; it neither pauses nor hides anything and touches
   none of pause, host away, player away, Get ready, results or drop. The pair that can happen
   — the host still running while the screen is open, and Back leaving mid-animation — is
   covered by "Back leaves the spike screen".
4. **Stay in the job's folder.** Only files under the allow list were written (the table
   above). The three `windows/flutter/generated_*` entries `git status` shows predate this job
   (10:52:25) and `git diff` on them is empty.
5. **Stop rather than overstep.** Nothing outside the allow list was needed. Where the work
   couldn't be done here — compiling and running the shader — the job stops at the tests and
   says so above rather than building or launching anything.

## Checks run

- `tools/check.sh format analyze look tv`: **PASS** format (2 s), **PASS** analyze (7 s),
  **PASS** look (10 tests, 4 s), **PASS** tv (11 s) — "All checks passed (24 s)".
- `flutter pub get` in the repository root after each `pubspec.yaml` change.
- `tools/review.sh` (uncommitted diff): **0 fail, 6 note** — the six are spacing literals in
  `shader_spike_screen.dart` (16, 8, 12, 4 px padding/gaps), the same kind the other screens
  carry until the look package's spacing scale lands.
- `dart analyze --fatal-infos` also run on its own: "No issues found!".

## Not sure about, questions, suggestions

1. **Not sure:** the shader's compile and draw were not observed here (see above). Nothing
   else in the diff depends on the shader running; both rows fall back.
2. **Suggestion (cost, for step 2/6):** one `FragmentShader` per shape per frame is a new
   allocation in the frame path — trivial at today's shape counts, worth measuring with
   `Stress: on` on the TV before pieces go through `toyShape` every frame. If the renderer
   copies uniforms at draw time, one shader per draw can be replaced by a small per-frame
   pool.
3. **Suggestion:** the created `FragmentShader`s are not disposed; they are collected, but
   the research lists Mali-Vulkan crashes around disposing shader resources, so I left
   disposal out rather than guess a safe moment.
4. **Decision I made that the brief didn't name:** the glint is clipped to the shape's path,
   so on a triangle it doesn't draw a white spot off the body. Say if it should not be clipped.
5. **Question:** the spike's Sunny background is a private const in the screen
   (`_background = Color(0xFF7CC8F8)`); step 2's token set will own that value — should the
   screen take it from `toy_look` then, or keep its own?
6. **Small risk:** `uSize` divides in the shader; a path with zero-height bounds (a line)
   would shade nothing. No shape does that today; a guard could be added when pieces use it.
7. **Test detail:** the turn test allows ±0.05 of a turn (0.4 s) so the first frame's phase
   doesn't matter; the 8 s period is not read back from the controller.

## Commit message

Add the toy_look package and the TV shader spike screen

New packages/toy_look holds the look's first slice: ToyShaders loads
toy_shade.frag once, times it and never throws (no shader = the Canvas
fallback), and toyShape draws a game object's shadow, body and ink outline,
with the shader or the hard-stop gradient and glint behind it. The TV app's
home gets a Look test button: the spike screen loads the shader, shows both
rows side by side, turns them, adds 60 stress shapes on demand and reads the
frame time, so the shader can be checked on each target before the look is
built on it. tools/check.sh gains the look check (10 tests).

## Status row

M13 step 1 (spike): the toy_look package (ToyShaders, toyShape, style, the Canvas fallback) and the TV Look test screen with 10 new look tests and 4 new TV tests are done and green; open: the shader's compile and draw on Windows, the Android TV emulator, a phone and an iPhone, and the frame time under Stress on each.

## Delete

- none

## Claude's review and device check (Nov 8)

Code: accepted. toyShape draws shadow, body, outline in order; one FragmentShader per draw (right: uniforms are read at draw time); uniforms by name; ToyShaders.load never throws. 10 look tests, tv passes.

Device check with a throwaway probe (both rows, then 64 more shapes per row, frame times from FrameTiming; not committed):

| Target | Renderer | Shader | Basic, raster avg | Stress (128 shapes), raster avg |
| --- | --- | --- | --- | --- |
| Windows, RTX 3080, release | Impeller (3.47 default) | loads in 5 ms | 4.9 ms | **71 ms** (shader-only 77, fallback-only 70) |
| Windows, same | Skia (`set_impeller_switch(Disabled)`) | loads in 7 ms | 1.2 ms | **4.8 ms** |
| Android 12 emulator, profile | Impeller OpenGL ES | loads | 15.9 ms | 15.2 ms (the emulator's own frame limit) |

Findings:
1. The shader compiles and draws on Windows (both renderers) and Android (Impeller GLES). Not yet seen: iPhone (Metal) and a real Android TV box; the owner's next device test covers them through the Look test screen.
2. Windows' Impeller is about 15 times slower at drawing many outlined, shadowed paths, with or without the shader: the shapes, not the shader. Decision: the Windows TV app runs on Skia (next job), re-checked at each Flutter upgrade, since Flutter says the opt-out will go in a future release.
3. The light turns with a rotated shape (the picture at 225° had its highlight at the bottom). Decision: the light stays at the screen's top-left; toyShape counter-rotates it from the canvas transform, for the shader and the fallback alike (next job).
4. Shader tuned by Claude: highlight from light > 0.86 (was 0.80: a third of the shape), glint radius 0.13–0.19 (was 0.09–0.14: too small to see).
