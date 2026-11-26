# m16 tail s2 report: the right hand's rects over a game no longer include Start

## Summary

Start/Pause moved into the slim game bar (owner, Nov 26), so `rightPadRects` no longer lists it. The change is in `rightPadRects` and its doc comment, and in the pins that read Start as one of its rects. Tests went first: with the old code, the 8 count pins failed (`Expected: <1> Actual: <2>` and similar), then the lib change made them pass.

Files changed:
- `controller_app/lib/src/ui/joined_view.dart`: `rightPadRects` drops `layout.start.shift(bar)` in dpad, gyro and sticks mode. Dpad and gyro return the face buttons only; sticks returns the face buttons and the right stick (or its floating zone). The doc comment now says the face buttons, and in stick mode the right stick, and that Start sits in the bar. File is 190 lines.
- `controller_app/test/right_pad_rects_test.dart`: the count pins go from 2/3/3/2 to 1/2/2/1 (D-pad, fixed sticks, floating sticks, gyro). Each test name now says "no Start button among them", and the expectation is `isNot(contains(startOf(...)))`. Test names and the other expectations are unchanged. The "Play on this phone" and "Show on this device" HUD tests are unchanged and pass.
- `controller_app/test/mirror_proof_test.dart`: `measure` took Start as `right.last`, which is now the right stick (or the face buttons in dpad). It now reads Start from `stickLayout` under the bar, the same way `startOf` does in the right-pad test. Added imports for `sticks.dart` and `top_bar_metrics.dart`. The comment no longer says Start is the last right rect.

Not changed, on purpose: `host_overrides.dart` (its `_hostHudRects` doc does not name Start, and it just forwards the list), `mirror_strip_proof_test.dart` (it reads `stickLayout(...).start` directly, not `rightPadRects`), `sky_holds_test.dart`, `joined_view_test.dart`, `pad_clearance_frame_test.dart`, `pad_clearance_screen_test.dart` (none of them reads `rightPadRects` or a HUD Start rect).

Tests run:
- Before the lib change: `flutter test test/right_pad_rects_test.dart test/mirror_proof_test.dart` gave `00:05 +14 -8: Some tests failed.` The 8 failures are the count pins.
- After the lib change: the same two files gave `+22: All tests passed!`.
- `tools/mine.sh`, first run: analyze `info - test\mirror_proof_test.dart:109:9 - The value of the argument is redundant because it matches the default value` (`mm: phonePxPerMm` in the `stickLayout` call). I removed the argument, since `stickLayout` defaults to `phonePxPerMm`, which is what `rightPadRects` gets here.
- `tools/mine.sh`, after the fix: `OK 44 tests controller_app`, `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- `flutter test test/mirror_proof_test.dart` (from `controller_app`, since it reads `../packages/...`): `+4: All tests passed!`.

Computed values, from the `measure` printout for `956.0x440.0` (wide) and `667.0x375.0` (narrow), first race puzzle `house`:
- wide: right rects `706.5,118.6 233.5x233.5 | 582.0,288.7 147.3x147.3` (stick mode, fixed). Start `482.0,198.0 66.0x40.0`, overlaps board true, gap 0.0 px. Strip room 118.6 px down. Mirror `208.1,145.3 77.2x79.8` at scale 1.287, hud `8.0,61.6 183.9x75.7`, twoLines.
- narrow: right rects `496.1,108.0 154.9x154.9 | 400.8,250.0 121.0x121.0`. Start `337.5,173.8 55.3x40.0`, overlaps board true, gap 0.0 px. Mirror null.
- all 18 puzzles: wide mirror placed 14, strip fits floor 18; narrow mirror placed 3, strip fits floor 18.

I did not capture the pre-change printout, so I cannot show a before/after of the mirror placed counts. The `measure` output is printed, not asserted, and the "every rect inside the box" and "strip fits" checks still pass.

Self-check (docs/review-rules.md part A):
1. Host setups: "Play on this phone" HUD test passes (right_pad_rects_test, host group); "Show on this device" gives no rects (same file). A joined phone and a peer one build older are not touched by this change (`rightPadRects` is only called from `joined_view.dart:170` and `host_overrides.dart:104`).
2. Kept state: none added or removed.
3. Combinations: the change only shortens a list; pause menu, host away, "Get ready", dropped link and leaving are not in these paths.
4. Stayed inside `allow:`; `git status` shows only the three files above (`pubspec.lock` unchanged; `flutter test` resolved packages without changing it).
5. No stop needed.
6. Looks: the right-pad pins run at portrait 1640x2360 (tablet) and landscape 852x393 (phone on its side), in all four modes; the HUD pins run at the host room 852x340 plus bar. No fixed pixel height was added.

## Hand-over

- Gate stopped after `rightPadRects` and its pins, as the brief says. The bar, pad widgets and `camera.dart` are untouched.
- The layout change is verified by tests only; no device check was run.

## Decisions

- Renamed the affected test names to say "no Start button among them" rather than keep a name that promises Start. The brief wanted the expected list changed, not the test removed; the name is the rule the test checks.
- `measure` in `mirror_proof_test.dart` now reads Start from `stickLayout` instead of `right.last`. The alternative (print `right.last` as "start") would have mislabelled the right stick as Start.
- The `joined_view.dart` doc comment says why Start is absent (it is in the bar above the pad), not what the code does.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m16 tail s2: rightPadRects drops Start, now in the game bar

Start/Pause moved into the slim top bar during games (owner, Nov 26), so
rightPadRects no longer lists it in any mode. Dpad and gyro return the
face buttons; sticks returns the face buttons and the right stick.
The pins now expect no Start rect (test names say so), and measure in
mirror_proof_test reads Start off the stick layout instead of right.last.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- m16 tail s2: done: rightPadRects drops Start (it is in the game bar since Nov 26); pins updated, tools/mine.sh OK (44 tests); open: device check of the HUD with no Start rect not run.

## Delete

- none
