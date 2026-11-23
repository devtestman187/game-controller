# M16 identity1-clean f1: StickPainter takes one StickGeometry

## Summary

- `StickGeometry` is a new const class in `stick_widgets.dart`: `center`, `radius`, `value`, with `==` and `hashCode`.
- `StickPainter` now takes `look`, `geometry`, `active`, `faint`, `fill` (5 named parameters, limit 5). `paint` reads `geometry.center/radius/value`; `shouldRepaint` compares `old.geometry != geometry`.
- StickPainter's doc now says the knob takes the fill's colour (the character's, else the player's), not "the player's colour".
- The stick widget's build and the two test constructions now pass `geometry: StickGeometry(...)` (the two tests use `const`). Assertions and test names are unchanged; no test added.
- No behaviour, colour or layout change. No other painter touched.

Tests run and seen in this job:
- `flutter test controller_app/test/pad_character_fill_test.dart`: All tests passed, 26 tests.
- `flutter test controller_app/test/pad_look_test.dart`: All tests passed, 16 tests.
- `tools/mine.sh`: first run FAILED on two `prefer_const_constructors` infos in the two tests; fixed by adding `const` to the `StickGeometry(` calls. Second run: `OK 47 tests controller_app`, RESULT ok.
- `tools/check.sh format analyze phone`: PASS format, PASS analyze, PASS phone.

Computed values: none; this is a refactor, the existing stick tests are the proof.

Self-check (review-rules part A):
1. Hosts: the stick is drawn by the same painter for every host setup; `pad_look_test.dart` and `pad_character_fill_test.dart` paint it (phone on "Play on this phone" / joined phone paths use the same widget). Covered by the existing tests above, unchanged expectations.
2. Kept state: none added; `StickGeometry` is a value object rebuilt per build.
3. Combinations: pause menu, away, "Get ready", dropped link, results, leaving: no new state; `shouldRepaint` still covers look, geometry, active, faint, fill.
4. Files: only the allowed files changed.
5. Nothing overstepped.
6. Looks: the menu look and the TV look are both exercised by the existing `pad_look_test.dart` (paintStick takes the look); no fixed pixel height added.

## Hand-over

- `tools/mine.sh` ran `dart format` on the touched files and reverted 3 generated files under `tv_test_app/windows/flutter/` (the churn check). Those three files were already modified in the starting git status; the revert is the tool's behaviour, not a change made by this job. Worth a look before the wave's commit.
- Git was not changed by this job (nothing staged or committed).

## Questions

1. The project rule says one public type per file. `stick_widgets.dart` already holds `StickModeView` and `StickPainter`; `StickGeometry` follows the brief and sits in the same file. Should it move to its own file (for example `stick_geometry.dart`) in a later job?
2. `StickPainter` still has magic numbers (`14.0`, `0.42`, `0.5`) in `paint`, which predate this job. Not touched here.

## Suggestions

- If `StickGeometry` moves to its own file, the tests keep importing `stick_widgets.dart`; they would need an extra import line.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
m16 identity1-clean f1: StickPainter takes one StickGeometry

StickPainter took center, radius and value as three parameters beside
look, active, faint and fill (7, over the limit of 5). They now travel
together in a const StickGeometry value object with ==/hashCode, so the
painter takes 5 named parameters. The knob's doc now names the fill's
colour (character, else player). Pure refactor: no behaviour, colour or
layout change; the stick tests are updated to the new constructor only.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- identity1-clean f1 done: StickPainter takes one StickGeometry (5 named parameters); pad_look 16 and pad_character_fill 26 tests pass, mine.sh and check.sh format analyze phone pass. Open: StickGeometry sits beside StickPainter in one file (one-public-type rule).

## Delete

- none
