# M16 identity1 w4 · f1 report: review fixes for wave A

## Summary

- **paintToyBadge takes a value object (review finding 1).** `paintToyBadge(Canvas canvas, Offset centre, double diameter, ToyLook look, ToyBadgeFace face)` is now five parameters, down from seven. `ToyBadgeFace` (in `toy_badge.dart`) holds `number`, `character` and `numbered` (default true). `ToyBadge`'s public constructor is unchanged and builds the face.
- **The no-number decision is recorded (finding 2).** `docs/decisions.md` has a new 2026-11-23 row at the end; `docs/design/look-and-sound.md` D10 now excepts the join screen's badge and the Settings preview.
- **Join badge pixel check (finding 3).** `controller_app/test/join_badge_test.dart` reads the painted screen and checks the badge's middle square is the disc's colour, on both looks.
- **Comments (findings 6 and 7).** The `numbered` doc on `ToyBadge` and the `paintToyBadge` doc name both callers (the join screen and the Settings preview). The ink-edge comment in `toy_badge_unnumbered_test.dart` is corrected.
- No new look, and numbered badges are unchanged: `toy_badge_test.dart` only moved to the new call.

### Tests first

- The three test files were changed first to the new call. `toy_badge_test.dart` and `toy_badge_unnumbered_test.dart` use `ToyBadgeFace`, which does not exist on the old code, so they do not compile there. I did not run them on the old code; this follows from reading the call.
- `join_badge_test.dart` compiles on the old code too: it only uses `ToyBadge`. Its new pixel test passes on the old code as well, because the old painter already draws no digit when `numbered` is false. So it did not fail first.
- The pixel test was proven to fail on a broken painter: I set `if (face.numbered)` to `if (true)` in `toy_badge.dart`, ran `flutter test controller_app/test/join_badge_test.dart`, and got 2 failures, one per look (`paints no digit`, menu look and TV look). I then reverted the mutation (verified by the final check run).

### Pixel check method (join_badge_test.dart)

- Screen read: the whole screen is drawn with `tester.binding.renderViews.first.debugLayer` (an `OffsetLayer`) `.toImage(Offset.zero & size)`, then `toByteData()`. `pumpApp` uses device pixel ratio 1, so one image pixel is one logical pixel. The screen is 852×393 (menu look) or 1180×820 (TV look), from `_pumpWithTealCrown`.
- The badge sits below the fold on the join screen, so the test calls `ensureVisible` on `find.byType(party.ToyBadge)` and settles before reading the box. Without this the read ran past the captured image (RangeError).
- Box: `tester.getRect(find.byType(party.ToyBadge))`, centre `box.center`.
- Middle square: half-side `box.width × _middleShare` with `_middleShare = 0.25`. A digit is about 0.2 of the diameter either side of the centre, so this holds it and stays inside the disc (the disc's inner ink edge is about 0.43 of the diameter from the centre, and the square's corners are about 0.35).
- Disc colour: sampled at `(centre.dx, centre.dy − box.width × 0.3)`, with `_discShare = 0.3`: inside the disc and above the digit.
- Expectation: every pixel in the middle square equals the disc sample, so `mismatched == 0`. The test passes at 0 on both looks. I did not compute an absolute colour value; the expectation is equality with the sample.
- Limit: the check reads colour equality only. It does not check the disc's own colour against the look, which the toy_look tests cover.

### Parameter count

- `paintToyBadge`: 5 (canvas, centre, diameter, look, face). Before: 7 (canvas, centre, diameter, number, look, character, numbered).
- `ToyBadge` constructor: unchanged (key, number, diameter, character, numbered).

### Self-check (review-rules part A)

1. Host setups: this is the controller app's join screen and Settings preview only; no host change. Covered by `join_badge_test.dart` (menu and TV looks).
2. Kept state: none added. Nothing starts or ends.
3. Combination with other states: the change is paint-only (no new state), so it sits under the pause menu, Get ready and the rest unchanged.
4. Stayed in the job's files: only the allowed list (see below).
5. Stop: `ToyBadgeFace` sits in `toy_badge.dart` with `ToyBadge`, so the file now has two public types (see question 1).
6. Every look: the join badge pixel test runs on the menu look and the TV look at the sizes in `_pumpWithTealCrown`. The `toy_badge` unit tests use the Sunny (menu) look only.

### Checks

- `tools/check.sh format analyze look phone`: all PASS (final run). `look`: 145 tests passed. `phone`: passed (the run prints no count).
- Earlier runs (for the record): the first run failed `format` (one file, fixed by `dart format`), `analyze` (one unnecessary `material` import, removed) and `phone` (the RangeError above, fixed by `ensureVisible`).
- Line endings: `toy_badge.dart` and `docs/decisions.md` are CRLF. I kept CRLF (the decisions row was appended with CRLF; `toy_badge.dart` was edited in place, and its lines still all end in CRLF).

## Files changed

- `packages/toy_look/lib/src/toy_badge.dart`: `ToyBadgeFace` added; `paintToyBadge` takes `(canvas, centre, diameter, look, face)`; `ToyBadge` builds the face; the `numbered` and `paintToyBadge` docs name both callers; the painter holds the face.
- `packages/toy_look/test/toy_badge_test.dart`: the two `paintToyBadge` calls use `ToyBadgeFace` (the second was reformatted by `dart format`).
- `packages/toy_look/test/toy_badge_unnumbered_test.dart`: two calls use `ToyBadgeFace(numbered: false)` and `ToyBadgeFace`; the comment at line 16 corrected (ink edge centred on the r=40 rim, 5.71 wide, inner edge about 37.1 from the centre).
- `controller_app/test/join_badge_test.dart`: pixel check added for the join badge on both looks (`_Screen`, `_screen`, `_middleShare`, `_discShare`); the `material` import removed, `rendering` added.
- `docs/decisions.md`: row 2026-11-23 appended (CRLF).
- `docs/design/look-and-sound.md`: D10 excepts the join screen's badge and the Settings preview.
- `docs/briefs/m16/identity1-w4/f1-report.md`: this report.

## Commit message — a draft

M16 w4 f1: badge face value object, no-number decision, pixel check

paintToyBadge now takes a ToyBadgeFace (number, character, numbered), five
parameters instead of seven; ToyBadge's constructor is unchanged. The join
screen's badge and the Settings preview draw no number because the phone has
no player number until the TV pairs; decisions.md and D10 record it. The join
badge test reads the painted screen and checks the disc's middle is one colour
on both looks; it fails when the painter ignores numbered.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

f1 (review findings 1, 2, 3, 6, 7) done: ToyBadgeFace value object, no-number decision in decisions.md and D10, join badge pixel check, comments fixed. Open: the review's other findings (generated plugin registrant files, the w4b check run, the file-size splits, the tests-first line in w4b).

## Delete

- none

## Questions

1. `ToyBadgeFace` is a second public type in `toy_badge.dart`, against G's one-public-type rule. I kept it there because the brief names that file. A separate `toy_badge_face.dart` would need adding to `allow:`. Say if you want it split.
2. The pixel check only proves the middle is one colour (no digit). It does not check the disc colour against the look; a positive control (a numbered badge's middle differs) is in `toy_badge_test.dart`, not in the join test.
3. `toy_badge_unnumbered_test.dart` and `toy_badge_test.dart` still use the Sunny look only; the TV look is not covered at the unit level.
4. Not in f1's scope and left alone: `tv_test_app/windows/flutter/generated_plugin_registrant.*` and `generated_plugins.cmake` are modified in the working tree (from the start-of-session status); the review's w4b checks item is open.
