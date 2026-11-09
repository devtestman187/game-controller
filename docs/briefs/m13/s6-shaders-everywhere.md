job: M13 step 6: shaders on everywhere: the drifting sky (toy_backdrop.frag) behind every menu and a still one in a round, both shaders loaded and warmed up at start, and the effects setting doing its whole job (design sections 4, 6 and D8)
pub: no
stop: after it.
read: docs/design/look-and-sound.md sections 1, 2 (D2, D3, D8), 4, 6 and 7 · docs/briefs/m13/s1-spike-report.md and docs/briefs/m13/research-flutter-shaders-report.md · packages/toy_look/lib and packages/toy_look/shaders (both .frag files; toy_backdrop.frag is new, written by Claude) · packages/toy_look/test/toy_background_test.dart and toy_shaders_test.dart · packages/party_host/lib/src/look_providers.dart, ui/puzzle_screen.dart, ui/game_screen.dart, ui/look_and_sound_section.dart, text/host_text.dart · controller_app/lib/main.dart and lib/src/ui/controller_screen.dart · tv_test_app/lib/main.dart and lib/src/ui/shader_spike_screen.dart and its rows · docs/review-rules.md · docs/coding-guidelines.md

Where it stands: every game object already goes through `toyShape` with `look.shade` (pieces, mirror, worker, marbles, bumpers, the HUD's paper, the game pictures). What's left is the sky, the start-up, and the setting.

Claude's rules:
1. **Two shaders, loaded once.**
   - `ToyShaders` gets `backdrop` (a `FragmentProgram?`) beside `shade`, with `backdropAsset = 'packages/toy_look/shaders/toy_backdrop.frag'`. Declare it under `flutter: shaders:` in toy_look's pubspec.
   - `load()` loads each on its own: one can fail while the other loads. `error` says which failed and why. It never throws.
   - **Warm-up:** after loading, `load()` draws each program once into a small offscreen picture (`PictureRecorder`, then `toImage` of a few pixels, then dispose), so the driver compiles it behind the splash and not on the first menu (design 6: a first use stalled about 1.5 s on Windows). It's timed in `loadMs`. A warm-up that throws counts as that shader failing.
   - `ToyLook` gets `backdrop` beside `shade`, null when effects are off (as `shade` is). Add it to `==` and `hashCode`.
   - The TV's shader spike screen shows each shader's state (loaded, or its error) and the load time.
2. **The sky, `ToyBackground`:**
   - It becomes a StatefulWidget with a Ticker (`SingleTickerProviderStateMixin`).
   - **Drift:** the dots move down and to the right on a diagonal at `toyDriftSpeed = 6.0` logical px per second. The shift is `(d, d)` with `d = (elapsed seconds × speed) % (2 × spacing)`, so the numbers stay small (the staggered grid repeats every two rows).
   - **When it drifts:** only when all of these hold: `look.backdrop != null`, `look.effects` is on, `MediaQuery.disableAnimationsOf(context)` is false, and nothing below it has asked for a still sky (next rule). Otherwise the ticker is stopped and the sky is painted once.
   - **Repaints:** only the sky repaints each tick. The `CustomPainter` gets `repaint:` a listenable of the shift, the child is not rebuilt, and the `RepaintBoundary` stays.
   - **Paint:** with `backdrop` it draws one full-box rectangle with the shader. Set the uniforms by name: `uSize`, `uBackground`, `uGlow` (straight 0..1), `uGlowShare` (0.6), `uDotAlpha` (the palette's `dotAlpha`), `uSpacing` (32), `uDotRadius` (3) and `uShift`. Without it, the Canvas painter as today, drawing its dots at the same shift. So the two draw the same picture at any shift, and turning effects on or off never makes the sky jump. One set of constants feeds both.
   - **One `FragmentShader` per painter**, made once and reused per frame: one shape, one set of uniforms. Dispose it with the painter's state.
3. **A still sky in a round:**
   - A widget `ToyStillSky({required Widget child})` asks the nearest `ToyBackground` above it to stop drifting while it's mounted, and lets it go again when it's removed.
   - Do it through a small inherited controller that `ToyBackground` provides. It counts holds, so two holders work, and a holder with no `ToyBackground` above it is fine.
   - Wrap the round's screens in it:
     - party_host's `PuzzleScreen` and `GameScreen`;
     - controller_app's `ControllerScreen` (the pad and the joined view: a phone in a round saves its battery).
   - The menus, the join screen, the results and every settings page still drift.
   - Covered pages need nothing: the navigator mutes tickers under an opaque page. Say so in the doc comment, and test it (next section).
4. **The effects setting's whole job** (D8: the shaders and the menu motion, this device only). Check every motion honours `look.effects` and list each in the report with the test that shows it:
   - button bounce, card pop, the ready card's pop;
   - the piece's boing, wobble and sparkle;
   - the worker's poses;
   - the goal's glow, the marble's recovering blink;
   - the sky's drift (new).

   Fix any that don't, test-first. Widgets also honour the OS's reduce-motion (`MediaQuery.disableAnimationsOf`) for the button bounce, the card pops and the drift. Painters have no context and keep using `look.effects` only.
   - Make the effects setting's subtitle (`HostText.effectsLine`) say what it now does in plain words, for example "Moving backgrounds, shading and bounces. Turn off on a slow device." Keep it short enough for the phone's settings row.
5. **What stays flat** (decided by Claude):
   - Menu badges and buttons stay flat, because text sits on them. The shade band would take ink-on-colour below 4.5:1 (D12).
   - The Arena's walls and goal pad are flat toy plates, as step 5 drew them.
   - Don't add `shade:` to any of them.
6. Files under 400 lines, functions under 60. Colours only through the look's tokens; the dots' white constant stays in toy_background.dart.

tests (each failing first):
- toy_look:
  - `ToyShaders.load()` loads both under `flutter test`;
  - a missing backdrop asset leaves `backdrop` null, keeps `shade`, and its `error` names the backdrop;
  - `ToyShaders.none` has neither;
  - `ToyLook.build(effects: false)` has no backdrop, and equality covers it.
- **The sky:**
  - with a backdrop and effects on it ticks: pump 1 s, and the shift moved by 6 px on each axis. Expose the shift for tests through a `@visibleForTesting` getter, or by reading the painter;
  - with effects off, with `disableAnimations`, without a backdrop, and under a `ToyStillSky`, it doesn't tick (`tester.hasRunningAnimations` is false, or the shift stays 0);
  - removing the `ToyStillSky` starts it again;
  - two holders: removing one keeps it still;
  - a page pushed over a drifting page: the one below stops ticking;
  - **same picture:** render the shader sky and the Canvas sky at the same shift, in Sunny and Night, at 300 × 200. Their pixels match within 3 per channel everywhere, except within 1.5 px of a dot's edge (anti-aliasing). Report the largest difference found;
  - only the sky repaints: a child counting its builds is built once over 10 ticks.
- party_host: `PuzzleScreen` and `GameScreen` hold the sky still, and the join screen and game picker drift.
- controller_app: `ControllerScreen` holds it still.
- The effects audit: one test per motion that had no effects test before, if any.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). Change only pins of `ToyBackground` being stateless, and list each.

## Claude's answers to the first run's report (Nov 9, 2026)

The first run stopped, rightly: `flutter test` can't load a fragment shader (docs/project-notes.md:115; the s1 spike). These answers replace the rules and tests above where they differ.

1. **Option B, with A's pure value.**
   - **The drift follows the setting, not the shader.** The sky drifts when `look.effects` is on, reduce-motion is off and no `ToyStillSky` holds it, whatever fills it.
   - **Fill:** the shader when `look.backdrop` isn't null, else the Canvas dots at the same shift. So a device without the shader drifts too, and "effects off" stays the switch for a slow device.
   - Tests see the drift through the Canvas fill.
2. **`ToySky`**, a small pure value in `lib/src/toy_sky.dart`, exported. It holds:
   - the sky's constants: spacing 32, dot radius 3, glow share 0.6, drift speed 6 px/s;
   - `Offset shiftAt(Duration elapsed)`: `(d, d)` with `d = (seconds × speed) % (2 × spacing)`;
   - the uniform values for a look, a size and a shift, as named values the painter sets by name.

   Both fills read it, so every number is a plain test.
3. **Loading:**
   - Contract tests as in s1: under `flutter test`, `load()` gives no programs, each with an error naming its own asset, and never throws.
   - `load()` takes an asset parameter per program (`shadeAsset:`, `backdropAsset:`).
   - "Keeps `shade` when the backdrop fails" is shown by the code's structure (two independent tries) and checked on a device, not in a test.
   - Timing: `loadMs` stays the whole load's time, and `shadeMs` and `backdropMs` give each program's load plus warm-up.
4. **The warm-up stays** (cheap, and a draw is what compiles on Skia). Whether it removes the Windows stall is my device check, not a test.
5. **`ToyStillSky`** and its hold counter go in their own file, `toy_still_sky.dart`.
6. **The goal glow's effects test** lands in this step, in `arena_paint_test`: with effects off the glow is the same at two round times; with effects on it differs.
7. **The TV's Look test screen gets a sky row**: a `ToyBackground` box in Sunny and one in Night, drifting, beside the shapes' row. It shows whether the backdrop shader loaded. That is the device check for the GLSL and the same picture; Claude runs it on Windows.

8. **Tests that settle.** A sky that ticks forever makes `pumpAndSettle` time out on every menu.
   - So `ToyStillSky` also works from above: a `ToyBackground` with a `ToyStillSky` anywhere above it (an inherited look-up) holds still too. Same widget, same meaning: "the sky is still here".
   - The test harnesses put one at their root: party_host's host harness, controller_app's `pumpApp`, tv_test_app's `pumpApp`, and any other test that pumps a `ToyBackground` and settles. Existing tests then keep settling unchanged.
   - The sky's own tests, and the holds tests for the screens, don't add one. A screen test asserts the hold through the background's state, not through settling.
   - The apps never put one at their root.

Tests now, replacing the sky and loading tests above:
- **ToySky:** `shiftAt(1 s)` is (6, 6); `shiftAt` wraps at 64; the uniform values for Sunny and Night (background, glow, dot alpha, spacing, radius, glow share, size, shift).
- **The sky with effects on** (no shader in tests, so the Canvas fill) ticks: after 1 s the painter's shift is (6, 6).
- **It doesn't tick** with effects off, with `disableAnimations`, or under a `ToyStillSky`.
- **Holds:** removing the `ToyStillSky` starts it again; with two holders, removing one keeps it still.
- **Covered pages:** a page pushed over a drifting page stops the one below ticking.
- **The Canvas fill's pixels:** at shift (0, 0) and (6, 6), a dot's centre moves by (6, 6).
- **Only the sky repaints:** a child counting its builds is built once over 10 ticks.
- **Loading:** the contract tests above, and `ToyLook.build(effects: false)` has no backdrop, with equality covering it.
- Reduce-motion for the button bounce and the card pops, and the goal glow's effects test.
- party_host and controller_app: the holds, as above.

in the report:
- test counts before and after;
- the files changed;
- each shader's load and warm-up time under `flutter test` (the number `loadMs` gives);
- the effects audit table (motion, where, honours effects, honours reduce-motion, test);
- the same-picture test's largest difference;
- any change to toy_backdrop.frag, and why (compile errors only).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s6-shaders-everywhere-report.md · packages/toy_look · packages/party_host · packages/puzzle_game · packages/test_game · controller_app/lib · controller_app/test · tv_test_app/lib · tv_test_app/test
check: format analyze look puzzle arena host phone tv kit
report: docs/briefs/m13/s6-shaders-everywhere-report.md
