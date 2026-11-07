# M12 step 4 report (from the worker's output; the brief left the report path off its allow list)

STATUS: done (G4, stopped at the gate)
CHECKS: format PASS · analyze PASS · phone PASS (275 tests) · review.sh 2 FAIL (both pre-existing long `build`s in moved code) · review.sh --strings 1 removed / 9 added / 141 unchanged
FILES: 16 (7 changed, 9 new) — all ≤300 lines; largest `settings_screen.dart` 290
Line counts (old → new): `controller_screen.dart` 456→150 · `controller_parts.dart` new 117 · `controller_top_bar.dart` new 164 · `pad_mode_view.dart` new 59 · `pad_widgets.dart` 421→248 · `face_buttons.dart` new 176 · `settings_screen.dart` 499→290 · `settings_sections.dart` new 244 · `controls_layer.dart` new 44 · `controls_settings.dart` new 29 · `providers/controls.dart` new 22 · `providers/game_feedback.dart` 82→96 · `providers.dart` 39→40 · `test/controls_layer_test.dart` new 215 · `test/game_controls_test.dart` 139→159 · `test/support/pump_app.dart` 117→140
Moves proved with `--strings` (0 removed, 0 added): screen split 35 unchanged or moved · face buttons 42 · settings sections 137. Final run adds only the new setting strings; the one removal is the reworded "Defaults" dialog text.
Tests: 262 before → 275 after (+12 in `controls_layer_test.dart`, +1 in `game_controls_test.dart`); no existing expected value changed.
Computed values: slider 20–100% at 10% steps = 8 divisions; 0.3 lands as 0.30000000000000004, so the test uses `closeTo(0.3, 1e-9)`; load clamps 0.1→0.2 and 1.5→1.0; tablet case is 1180×820 `tablet: true, isIOS: true`.
QUESTIONS:
1. Deviation: `PadModeView` had to become a real library (`ui/pad_mode_view.dart`, 59 lines) instead of part of `controller_parts.dart` — a part can't be imported, and `ControlsLayer` (own file, Q1) must build it. Content unchanged; the part keeps `DemoReadout`, `TooSmallView`, `openControl`, plus the new `_Controls`.
2. The brief's `report:` path `docs/briefs/m12/s4-report.md` is outside my allow list (lib + test only), so no report file was written; details are here.
3. `review.sh` still FAILs `_TopBar.build` (126 lines at HEAD, 129 now) and `_HapticsSection.build` (70 at HEAD, 70 now): moved verbatim, pre-existing tech debt. `ControllerScreen.build` went 89 → 53 (two small extractions), so it no longer fails.
4. `gameShownProvider` has no setter caller in `lib` yet (only tests), by design for steps 5–6; flagging in case the analyzer/dead-code review minds.

## Commit message
M12 s4: the controls layer and the controls' opacity over a game

Split `controller_screen`, `pad_widgets` and `settings_screen` into part
files (pure moves; `--strings` 0 added, 0 removed).
Add `ControlsLayer` (opacity over a `RepaintBoundary`; touches only on the
controls), `ControlsSettings` (`controlsOpacity`, 0.6, 0.2–1.0, clamped) and
`gameShownProvider`, false until steps 5–6.
The body stack now asks the layer for the opacity, and the status panel
hides while a game shows.
Settings: a "Game on this phone" section with the opacity slider, reset by
Defaults. Tests: 262 → 275.

## Status row
| 4 Controls layer, opacity | **G4 done** (s4): moves (`controller_parts`, `controller_top_bar`, `face_buttons`, `settings_sections`, plus `pad_mode_view` as its own library — a part can't be imported by `ControlsLayer`), `ControlsLayer` + `ControlsSettings` (`controlsOpacity`, 0.6, 0.2–1.0) + `gameShownProvider` (never set true yet), settings section and reset; 275 tests, `review.sh` 2 FAILs are the moved long `_TopBar`/`_HapticsSection` builds. Open: steps 5–6 must set `gameShownProvider` and give the layer a child

## Delete
- none
