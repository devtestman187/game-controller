# M13 step 6: shaders everywhere (stopped before code: the brief's shader tests can't run)

Job: `docs/briefs/m13/s6-shaders-everywhere.md`. Gate: G4, the whole step.
**Status: stopped.** The brief's test list and the project's own record disagree on one fact, and
that fact carries the whole job: **no `FragmentProgram` can be loaded under `flutter test`**, so the
drifting sky, the two-program load and the same-picture check cannot be shown by a test here. Coding
guidelines §11 ("if the brief's contract can't be met as written … stop and report it, never work
around a design problem") and review-rules A5 say stop. No `lib/` file was changed; this report is
the whole diff, plus one throwaway probe test listed for deletion.

## The blocker, in one line

Rule 2 makes the sky drift only when `look.backdrop != null`, and the test list asks for that drift
to be tested — but under `flutter test` `ToyShaders.load()` can never give a program, so **no
`ToyLook` in any test can have `backdrop != null`** and the sky can never drift in a test.

## The evidence (probed on this machine, not from memory)

A throwaway probe in `packages/toy_look/test/probe_tmp_test.dart`, run with `flutter test`:

```
OFL OK, 4481 chars                                    # ordinary assets are in the test bundle
FONT OK, 159184 bytes
FRAG SOURCE FAILED: Unable to load asset: "packages/toy_look/shaders/toy_backdrop.frag".
  The asset does not exist or has empty data.         # the shaders/ entries aren't there at all
BACKDROP FAILED: Exception: Asset 'packages/toy_look/shaders/toy_backdrop.frag' not found
SHADE FAILED:    Exception: Asset 'packages/toy_look/shaders/toy_shade.frag' not found
```

`flutter test` (3.47.8) builds a test bundle from `flutter: assets:` and `fonts:` only: it never runs
impellerc, so there is no compiled `.frag` and not even the source under `shaders/`. `flutter test
--help` has no option that changes this, and `FragmentProgram` has no `fromBytes` to load a compiled
blob by hand. This is already recorded as a lesson: `docs/project-notes.md:115` — "`flutter test`
doesn't load fragment shaders … Shader code is tested through its Canvas fallback, and its real
drawing is checked on a device (M13 spike)" — and in `docs/briefs/m13/s1-spike-report.md` ("It doesn't
work, and it fails cleanly"), where the shader test asserts the contract instead.

## Each brief test that cannot pass, and why (one cause)

| Brief's test | Why it can't run |
| --- | --- |
| `ToyShaders.load()` loads both under `flutter test` | neither asset is in the test bundle |
| "a missing backdrop asset leaves `backdrop` null, **keeps `shade`**, and its `error` names the backdrop" | with no loadable asset, `shade` is null too in every test, so "keeps shade" can't be shown |
| "with a backdrop and effects on it ticks: … the shift moved by 6 px on each axis" | needs `look.backdrop != null`, impossible in a test |
| "removing the `ToyStillSky` starts it again", "two holders: removing one keeps it still", "a page pushed over a drifting page: the one below stops ticking" | all three need a sky that drifts first |
| "same picture: render the shader sky and the Canvas sky at the same shift … within 3 per channel" | needs a real program (and its "largest difference" for the report) |
| "each shader's load and warm-up time under `flutter test` (the number `loadMs` gives)" | `loadMs` would only ever time a failure |
| `ToyLook.build(effects: false)` has no backdrop, equality covers it | this one is fine; its "with a backdrop" counterpart is not buildable |

The negative cases (effects off, `disableAnimations`, a `ToyStillSky`) are testable, but they only
prove the sky never drifts — which is the one thing a broken build also does, so they are no proof.

## What is not blocked (read-only survey, so the re-brief is cheap)

Everything else in the brief is reachable today, with the file each change lands in and what it does.
I did **not** start it, because the shape of the sky's fill depends on the answer below.

| File | Change the brief asks for (not done) |
| --- | --- |
| `packages/toy_look/pubspec.yaml` | `- shaders/toy_backdrop.frag` under `flutter: shaders:` (only `toy_shade.frag` is declared today) |
| `lib/src/toy_shaders.dart` | `backdrop` + `backdropAsset`, each program loaded on its own, `error` naming which failed, the warm-up draw, `loadMs` |
| `lib/src/toy_look.dart` | `backdrop` field, null when effects are off, in `build`, `==` and `hashCode` |
| `lib/src/toy_background.dart` (now 79 lines, stateless) | `StatefulWidget` + `SingleTickerProviderStateMixin`, the shift listenable, the shader or Canvas fill from one set of constants, one `FragmentShader` per painter |
| `lib/src/toy_still_sky.dart` (new) | `ToyStillSky` and the inherited hold-counter controller (keeps `toy_background.dart` under 400 lines and one responsibility) |
| `packages/party_host/lib/src/ui/puzzle_screen.dart`, `game_screen.dart` | wrap the round in `ToyStillSky` |
| `packages/party_host/lib/src/text/host_text.dart:342` | `effectsLine` → e.g. "Moving backgrounds, shading and bounces. Turn off on a slow device." |
| `controller_app/lib/src/ui/controller_screen.dart` | wrap the pad and the joined view in `ToyStillSky` |
| `tv_test_app/lib/src/ui/shader_spike_screen.dart`, `src/tv_text.dart` | show each shader's state and its load time (`_status` at line 94 is the one-shader version) |
| tests | `toy_background_test`, `toy_shaders_test`, `toy_look_test`, party_host screens, `controller_screen`, plus the effects-audit gaps below |

**Reduce-motion does not exist anywhere yet:** `MediaQuery.disableAnimationsOf` appears in no file in
the repository, so the brief's "widgets also honour the OS's reduce-motion for the button bounce, the
card pops and the drift" is new code in `toy_button.dart`, `toy_card.dart` and the sky. That part is
fully testable under `flutter test` and is independent of the blocker.

## The effects audit (brief rule 4), read from the code

| Motion | Where | Honours `look.effects` | Honours reduce-motion | Test |
| --- | --- | --- | --- | --- |
| button bounce | `toy_button.dart:149, 219` | yes | **no** (not implemented) | `toy_button_test.dart:143` |
| card pop | `toy_card.dart:80` | yes | **no** (not implemented) | `toy_card_test.dart:115` |
| ready card's pop | `ready_card.dart:94` | yes | **no** (AnimationController, no check) | `ready_card_test.dart:41` |
| piece boing | `puzzle_painter.dart:261`, `mirror_painter.dart:137` → `PieceMoments` | yes | n/a (painter, no context — by design) | `piece_moments_test.dart:112` |
| piece wobble | `puzzle_painter.dart:262` | yes | n/a | `piece_moments_test.dart:113` |
| piece sparkle | `puzzle_painter.dart:349-350` | yes | n/a | `piece_moments_test.dart:114-115` |
| worker's poses (blink, effort) | `worker_painter.dart:71` → `WorkerMoments` | yes | n/a | `worker_moments_test.dart:288-303` |
| the goal's glow | `arena_painter.dart:140` | yes | n/a | **none** — the one motion with no effects test |
| marble's recovering blink | `arena_marble_painter.dart:93` | yes | n/a | `arena_paint_test.dart:244` |
| the sky's drift | new | — | — | — |

So the audit finds the code already honouring `effects` for all nine motions; what step 6 would add is
the drift, reduce-motion for the three widgets, and the goal-glow test the brief asks for.

## Options for Claude (each is a design decision, so I took none)

- **A. Keep the rules, test what the format allows.** Contract tests for `load()` as in s1; unit-test
  the drift's arithmetic (a pure `toyShift(elapsedS)`-style helper shared by both fills) and the
  Canvas fill's pixels at two shifts; check the shader's drawing on a device through the TV's Look
  test screen, with a backdrop row added. The "same picture" guarantee becomes a device check.
- **B. Drift on `effects` alone, fill chosen by `backdrop`.** Then a widget test can see the sky tick
  (effects on, `backdrop` null → Canvas dots drift). This reads as the intended look anyway ("turning
  effects on or off never makes the sky jump", "one set of constants feeds both"), but the GLSL is
  still untested.
- **C. A seam for the fill.** A small `ToySkyFill` interface in `toy_look` (the shader's one, and the
  Canvas one), with the painter taking one: tests can then exercise the drift and read the uniforms a
  fake received, and the two implementations can be compared on a device. More API than the brief has.
- **D. A device test.** `integration_test` on a real device would load the shader; no `flutter test`
  check in `tools/check.sh` covers it.

**Suggestion (not acted on):** A plus the brief's own "one set of constants feeds both": a small pure
`ToySky` value (spacing, radius, glow share, the shift from elapsed time, and the uniforms worked out
from a look) that both fills read. Then every number in rule 2 — the 6 px per second, the
`(d, d)` diagonal, the `% (2 × spacing)` wrap at 64, each uniform's value — is a plain test, the
Canvas picture is a pixel test, and only the GLSL needs a device. That is one new file in `toy_look`
and no new public behaviour.

## Self-check (review-rules.md part A, one line each)

1. **Every host setup.** Not affected: no behaviour changed (TV host, phone "Play on this phone",
   phone "Show on this device", joined phone, older peer) — the only changed file is this report.
2. **When kept state starts and ends.** Nothing is held: no ticker, timer or cache was added.
3. **How a new state combines with the others.** No new state; pause, away, Get ready, results and
   leaving are untouched.
4. **Stay in the job's folder.** Only this report and one probe test under `packages/toy_look/test`
   were written; the probe is listed under Delete.
5. **Stop rather than overstep.** This report is that answer: the shader-load fact makes the brief's
   contract unmeetable here, and the fix is a design decision for Claude, not a workaround by me.

## Checks run

- `tools/check.sh format analyze look puzzle arena host phone tv kit`: **all PASS** (109 s, run again
  after the report was written) —
  format, analyze, kit 48 tests, look 94, arena 61, puzzle 171, host 203, phone 403, tv (printed no
  count because of its one skipped test; `flutter test` in `tv_test_app` says 50 passed, 1 skipped).
  This is the before count; there is no after count, because no test was added.
- The probe above, run with `flutter test test/probe_tmp_test.dart`; the file now holds no tests
  (`look` still reports 94) and is listed for deletion.

## Not sure about, questions, suggestions

1. **Question:** which option (A, B, C or D) — and if A, may the pure `ToySky` helper land in
   `lib/src/` as a small public value (it is what makes the brief's numbers testable)?
2. **Question:** does the warm-up actually help? `research-flutter-shaders-report.md` §4 cites
   flutter#193048 (awaiting `fromAsset` no longer warms a Windows shader; the first frame still froze
   ~1.5 s) — so the brief's "draw each program once into an offscreen picture" may not remove the
   stall on Windows. A device check is what settles it; a test here can only show the draw is made.
3. **Not sure:** with two programs, is `loadMs` one number for the whole `load()` or one per program?
   The brief says "it's timed in `loadMs`" and also asks for "each shader's load and warm-up time".
4. **Not sure:** should `ToyStillSky` be its own file (`toy_still_sky.dart`) or stay inside
   `toy_background.dart`? I would split, to keep one responsibility and the file small.
5. **Suggestion:** the TV's Look test screen is the only place the backdrop shader is ever seen
   drawing; adding a backdrop row there (Sunny and Night, drifting) would give the device check
   something to look at, next to the shapes' row.
6. **Not sure:** the goal glow has no effects test, and adding one (as the brief allows: "one test per
   motion that had no effects test before") needs a pixel or painter probe in `arena_paint_test`;
   say if that is wanted in the same step.

## Commit message

Add the M13 step 6 report: the shader tests can't run under flutter test

The step's plan is sound but its test list leans on a FragmentProgram
under flutter test, and the test bundle has no compiled shaders at
all: FragmentProgram.fromAsset fails for both keys on this machine,
while ordinary assets load. Since the sky drifts only with a loaded
backdrop and no test can have one, the drift, the load, the warm-up
and the same-picture check cannot be shown here. This report records
the evidence, the audit of the effects setting (all nine motions
already honour it; reduce-motion exists nowhere yet, and the goal's
glow has no test) and four options for the way on.

## Status row

M13 step 6 (shaders everywhere): stopped before code — `flutter test` cannot load a fragment shader, so the brief's drift, load, warm-up and same-picture tests cannot pass; open: Claude's choice of option A–D, then the whole step.

## Delete

- packages/toy_look/test/probe_tmp_test.dart
