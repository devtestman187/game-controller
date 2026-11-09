# M13 step 6: shaders everywhere (second run: the sky on every menu, still in a round)

Job: `docs/briefs/m13/s6-shaders-everywhere.md`, following its section "Claude's answers to the
first run's report (Nov 9, 2026)". Gate: G4, the whole step. **Status: done.** This report replaces
the first run's (which stopped on the shader tests).

## What the step now does

Option B, as answered: the drift follows `look.effects`, not the shader. `ToyBackground` is a
`StatefulWidget` whose ticker runs while effects are on, the device doesn't ask for reduced motion
and no `ToyStillSky` holds the sky. Each tick sets a `ValueNotifier<Offset>` of the shift, which the
painter repaints from; the child isn't rebuilt. The fill is the backdrop shader when
`look.backdrop != null`, the Canvas dots at the same shift otherwise, both reading `ToySky` for
every number. A round's screens (`PuzzleScreen`, `GameScreen`, `ControllerScreen`) wrap themselves
in `ToyStillSky`, through a counted hold below the sky and a mark above it for harnesses and for a
`ToyBackground` under a still sky. `ToyShaders` loads the two programs independently, warms each up,
and reports `loadMs`, `shadeMs` and `backdropMs`; the TV's Look test screen shows each program's
state and gained a drifting sky row in Sunny and Night.

## Files changed

New:
- `packages/toy_look/lib/src/toy_sky.dart` — the sky's constants (spacing 32, radius 3, glow share 0.6, speed 6), `shiftAt`, and the shader's uniform values; both fills read it.
- `packages/toy_look/lib/src/toy_still_sky.dart` — `ToySkyHolds`, `ToySkyHoldsScope`, `ToyStillSky` and the above-the-sky look-up.
- `packages/party_host/test/sky_holds_test.dart` — the home, the picker and the join screen drift; the Shape Race round and the Arena screen hold still.
- `controller_app/test/sky_holds_test.dart` — Connect drifts; the pad holds still.
- `docs/briefs/m13/s6-shaders-everywhere-report.md` — this report.

Changed:
- `packages/toy_look/lib/src/toy_background.dart` — stateful with a ticker, the hold, the shader/Canvas fills at one shift, repainting from the shift alone.
- `packages/toy_look/lib/src/toy_shaders.dart` — a backdrop program, a per-program load and error with asset parameters, `shadeMs`/`backdropMs`, the warm-up kept.
- `packages/toy_look/lib/src/toy_look.dart` — `backdrop`, gated by effects, in `==` and `hashCode`.
- `packages/toy_look/lib/toy_look.dart` — exports the two new files.
- `packages/toy_look/pubspec.yaml` — `shaders/toy_backdrop.frag` declared.
- `packages/toy_look/lib/src/toy_button.dart` — the focus bounce also honours reduced motion.
- `packages/toy_look/lib/src/toy_card.dart` — the pop-in also honours reduced motion.
- `packages/party_host/lib/src/ui/ready_card.dart` — the count's pop also honours reduced motion.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — the round wrapped in `ToyStillSky`.
- `packages/party_host/lib/src/ui/game_screen.dart` — the Arena screen wrapped in `ToyStillSky`.
- `packages/party_host/lib/src/text/host_text.dart` — `effectsLine` says what the setting now does.
- `controller_app/lib/src/ui/controller_screen.dart` — the pad and joined view wrapped in `party.ToyStillSky`; the long `build` split into `_body`, no behaviour change.
- `tv_test_app/lib/src/tv_text.dart` — the spike's sky labels and a per-shader state line.
- `tv_test_app/lib/src/ui/shader_spike_screen.dart` — the sky row (Sunny and Night), the two shader state lines, the shapes tab extracted to `_shapesTab`.
- `tv_test_app/test/shader_spike_screen_test.dart` — the new status prefixes and the sky-row test.
- `tv_test_app/test/support/pump_app.dart` — a still sky above the app.
- `tv_test_app/test/toy_gallery_test.dart` — a still sky.
- `controller_app/test/support/pump_app.dart` — a `stillSky` flag, on by default, for `pumpApp` and `pumpFaked`.
- `packages/party_host/test/support/host_harness.dart` — a `stillSky` flag; `puzzleDataDir` resolves from the package or the repo root, so a single host test file runs from either.
- `packages/toy_look/test/toy_background_test.dart` — the `ToySky` values, the drift, the still cases, the holds, a covered page, repaint isolation, and the Canvas pixels.
- `packages/toy_look/test/toy_shaders_test.dart` — the loading contract, a missing asset's own error, `none`.
- `packages/toy_look/test/toy_look_test.dart` — no backdrop with effects off; equality covers it.
- `packages/toy_look/test/toy_button_test.dart` — a reduced-motion bounce test; a still-sky root.
- `packages/toy_look/test/toy_card_test.dart` — a reduced-motion pop test; a still-sky root.
- `packages/toy_look/test/page_transitions_test.dart`, `packages/toy_look/test/toy_pill_test.dart` — a still-sky root (the pins of `ToyBackground` being stateless).
- `packages/party_host/test/ready_card_test.dart` — a reduced-motion test; a still-sky root.
- `packages/party_host/test/look_and_sound_test.dart` — the new `effectsLine`; no backdrop with effects off.
- `packages/test_game/test/arena_paint_test.dart` — the goal glow's effects test.

Not mine (in the working tree, outside `allow:`):
- `docs/design/look-and-sound.md` — one line, already changed when this run started: your Nov 9 decision that the drift follows the setting, not the shader. I didn't edit it.
- `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake` — rewritten by the Flutter tool on `pub`/test runs; line endings only (no content diff). I didn't edit them.

## Computed test values

- `ToySky.shiftAt(1 s)` = (6, 6); 10666 ms = 63.996, 10667 ms = 0.002 (wraps at 2 × 32).
- Uniforms: Sunny dot alpha 0.22, Night 0.07; spacing 32, radius 3, glow share 0.6.
- Canvas pixels, 300 × 300: glow centre (196, 234, 255) ±1; far corner (124, 200, 248); half-way red ≈ 160 ±3; a Sunny dot at (272, 288) is (153, 212, 250) ±2, Night's (51, 44, 105) ±2.
- The same dot at shift (6, 6) is at (278, 294); its old centre is the plain background.
- Ticks: after 1 s the shift is (6, 6), after 2 s (12, 12).
- Only the sky repaints: the counted child builds once over ten 100 ms ticks.
- A covered page stops the sky below within the 400 ms after a push (its 300 ms slide included).
- Button: bounce peaks at 1.06 and rests at 1.04. Card pop: 0.9 → 1.0 in 180 ms. Ready count: 1.3 → 1.0 in 250 ms.
- Goal glow: the sample at (815, 270) differs between t = 0 and t = 0.5 s and between t = 0.25 and t = 0.5 s with effects on, and is equal with them off.

## Test counts

| check | before | after |
| --- | --- | --- |
| kit | 48 | 48 |
| look | 94 | 107 |
| arena | 61 | 62 |
| puzzle | 171 | 171 |
| host | 203 | 206 |
| phone | 403 | 405 |
| tv | 50 passed, 1 skipped | 51 passed, 1 skipped |

1030 → 1050 passed, 1 skipped. Twenty new tests: look 13, arena 1, host 3, phone 2, tv 1.

## Shader load and warm-up under `flutter test`

`ToyShaders.load()` gives `loadMs` 4, `shadeMs` 3, `backdropMs` 0 in the contract test. Under
`flutter test` both keys are missing (`Asset '…toy_shade.frag' not found`), so these are the failed
look-ups, not a real load and warm-up: the warm-up's cost can't be timed here. On a device the TV
spike's "Shade: on (N ms)" and "Backdrop: on (N ms)" are that number. The contract test asserts each
time is ≥ 0, the whole ≥ each part, and that neither throws.

## The effects audit

| Motion | Where | Honours effects | Honours reduce-motion | Test |
| --- | --- | --- | --- | --- |
| The sky's drift (new) | `ToyBackground`, every page | yes (`look.effects`) | yes | toy_background_test: "with effects on the sky ticks…"; "with the effects off the sky stays still"; "with reduced motion asked for the sky stays still" |
| Button bounce | `ToyButton`'s focus scale | yes | yes (added) | toy_button_test: "with effects off the focus sits at 1.04 at once, with no bounce"; "with reduced motion asked for the focus sits at 1.04 at once, with no bounce" |
| Card pop | `ToyCard`'s pop-in | yes | yes (added) | toy_card_test: "with effects off or popIn false it appears at 1.0 at once"; "with reduced motion asked for the card appears at 1.0 at once" |
| Ready card's pop | `party_host`'s `ReadyCard` count | yes | yes (added) | ready_card_test: "with the effects off the count is still"; "with reduced motion asked for the count is still" |
| Piece's boing | `PuzzlePainter`, `MirrorPainter` | yes | no (a painter has no context; as the brief says) | piece_moments_test: "with the effects off none of it moves" |
| Piece's wobble | same | yes | no | same test |
| Piece's ✓ sparkle | same | yes | no | same test |
| Worker's poses (hop, shake, blink, lean) | `WorkerMoments`, `WorkerPainter` | yes | no | worker_moments_test: "with the effects off nothing hops, shakes, blinks or leans" |
| Goal's glow | Arena's goal painter | yes | no | arena_paint_test: "the goal glow pulses with effects on and is still with them off" (new) |
| Marble's recovering blink | Arena's marble painter | yes | no | arena_paint_test: "a recovering marble fades with effects on and is still with them off" |

## The same-picture check

Not measurable under `flutter test`: the backdrop program never loads, so there is no shader
picture to compare with the Canvas one, and no largest difference to report. What the tests pin is
the Canvas side: `ToySky` is the only source of the numbers and the painter gives the shader
`ToySky.uniforms`, so a device draws both fills from the same values. The device check is the TV
Look test screen's sky row (Sunny and Night beside each other): you run it on Windows.

## `toy_backdrop.frag`

Unchanged — no compile errors were seen, and the painter's uniform names match it: `uSize`,
`uBackground`, `uGlow`, `uGlowShare`, `uDotAlpha`, `uSpacing`, `uDotRadius`, `uShift`.

## Self-check: docs/review-rules.md part A

1. **Every host setup.** The change is in the look layer, which every setup draws through: TV/PC host, Play on this phone, Show on this device and a joined phone all get a `ToyBackground` page. Host screens and the pad are tested (party_host `sky_holds_test`, controller_app `sky_holds_test`); a build one older has no message change and keeps its own still sky.
2. **When kept state starts and ends.** The ticker runs only while effects are on, motion isn't reduced and no hold stands; it stops on any of those, on an opaque page above (TickerMode) and on dispose. A hold is counted and released in `dispose`; a release with no hold asserts and is ignored. No round is needed for it to run, and none stops it early. Tested by the still cases and the holds test in toy_background_test (resuming where it stood is not asserted separately).
3. **How a new state combines.** `ToyStillSky` wraps a whole round route, so the pause menu, the host away, a player away, Get ready and the results stay under the one hold while that route is up; leaving releases it (controller_app's pad test covers the pair Press/live and leave indirectly; the host round test covers the round's start). The pause and away overlays are not separately tested with the sky.
4. **Stay in the job's folder.** All my writes are inside `allow:` (the files above). The working tree also shows `docs/design/look-and-sound.md` (your Nov 9 line) and three generated Windows plugin files — neither was edited by me (see "Not mine").
5. **Stop rather than overstep.** Not needed this run: your answers resolved the shader-load blocker. The only deviation is the review tool's two long-`build` FAILs, fixed by extracting `_body` and `_shapesTab` (no behaviour change).

## Questions and suggestions

1. `docs/design/look-and-sound.md` and `tv_test_app/windows/flutter/generated_*` are modified in the
   working tree though outside `allow:`. I left them alone — please confirm they're yours (the doc
   line matches your answer 1).
2. Under `flutter test` the shader times are failed look-ups (3 ms and 0 ms). If you want the warm-up
   measured, the TV spike's lines are the place; a second's pause before the first menu would show a
   warm-up that isn't working.
3. `ToySky`'s four constants are literal design numbers in one place; `tools/review.sh` notes each as
   a numeric literal (notes, not FAILs), as it does for other design constants.
4. Every `ToyBackground` state makes its own `FragmentShader` from the shared program (one per page,
   as briefed). If pages ever multiply, making one per program would save a little; not worth it now.

## Claude's review (Nov 9, 2026)

Accepted, with these changes. Counts after them: look 108, tv 51 (+1 skipped); the rest as above.

- **Answers to the questions:** the design doc line and the generated Windows files are mine (the generated ones are reset before every commit). The literal notes and one shader per page are fine.
- **The sky no longer disposes its `FragmentShader`**, matching the warm-up: the research lists Mali-Vulkan crashes around disposing shader resources, and a retained layer may still hold it for a frame.
- **The device check, on Windows** (profile build, Skia):
  - Shade loaded in 3 ms and Backdrop in 0 ms.
  - Frames averaged 1.2 ms (2.1 ms worst) with the shapes turning and four skies drifting.
  - The dots moved about 14 px down and to the right in about 2.4 s, the 6 px a second planned.
  - The new effects line reads as written.
- **The sky row now shows each palette twice,** with the shader and then with the fallback, so a device shows the same-picture check side by side. On Windows the two are indistinguishable in Sunny and in Night: same glow, same dots.
  - Its labels take the screen's text colour, not the box's: a Night label was white, unreadable on a Sunny screen.
- **Tabs read on the background:** the TV Look test's unselected tab was Material's dark default on the Night sky. `toyTheme` now gives `TabBar` onBackground labels and underline, tested in both palettes.
- **Still to check on devices (step 9):** the warm-up's effect on a cold first menu, and the sky on the Android TV, phones and iPhone.

## Commit message

M13 step 6: the sky drifts on menus and stands still in a round

ToyBackground ticks while effects are on and nothing holds it,
painting the backdrop shader when it loaded and the Canvas dots
at the same shift otherwise; every number comes from ToySky.
ToyShaders loads and warms both programs independently, with a
per-program error and time. PuzzleScreen, GameScreen and the
pad wrap themselves in ToyStillSky. Button, card and ready-card
motion also honours reduced motion; the TV Look test shows each
shader's state and a drifting sky in both palettes.

## Status row

M13 step 6 (shaders everywhere): done — the sky drifts on menus and holds still in a round with or without the shader, both programs load and warm up at start, the effects setting covers every motion, and the TV Look test shows each shader's state and a sky row for the device check.

## Delete

- none
