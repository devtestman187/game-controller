## Summary

Job m16 m165 c4 (B-044): tests only, no lib change. Added three tests in a new group in
`packages/puzzle_game/test/hud_place_right_controls_test.dart`, pinning that `place()` and the
mirror's rect and scale ignore the right hand's controls, and that the clock area moves clear of a
control over its spot. All six tests in the file pass on the code as it is (the brief marks this
tests-first exempt: the behaviour already holds on the base, and the test pins it).

Decisions:
- The mirror setup is house, `phone169` (667 x 375), `sideLeft`, `raceText(house)` text, as
  `mirror_place_test.dart` sets it up. `phone169`, `raceText` and `sideLeft` come from
  `support/mirror_helpers.dart` by a `show` import, because that file and `match_helpers.dart` both
  define `load`.
- The control over the board's centre is a 40 x 40 rect centred on `world.origin + board.center * world.scale`
  (the board's centre in the box's px). The constant is `handPx`, not a bare number.
- The clock spot is the `hud.rect` from `mirrorPlace` with `hudRects: const []`.
- "null in both counts as identical" is not used: the first test asserts the free mirror is non-null,
  so the comparison is not vacuous.

## Files changed

- `packages/puzzle_game/test/hud_place_right_controls_test.dart`: added the `mirror_helpers` import
  (`show`), a `handPx` constant, and a group with three tests: mirror rect and scale unchanged by a
  control over the board's centre; `place()` origin and scale unchanged before and after a mirror fit
  with such a control; the clock area moved clear of a control over its spot, with `mirrorGapPx`.
- `docs/briefs/m16/m165/c4-report.md`: this report.

## Checks

- `tools/mine.sh`: `OK 6 tests packages/puzzle_game`, `RESULT: ok: 1 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. Run once; no fix was needed, so it ran once.
- Computed values: none printed. The expectations are relations between two calls (before/after,
  with/without a control), not numbers, so no literal was computed by hand. The rects themselves were not
  printed (no print in tests).
- Expected to fail on the base: no; the tests pass on the current code, as the brief says.

## Questions

- The `place()` test compares `place` with itself before and after the mirror fit, since `place` takes no
  `hudRects`. It is correct but cannot fail; the stronger check is the mirror rect/scale test above it.
  Keep it as the brief asks, or drop it?
- The clock-area test only checks overlap with the spot inflated by `mirrorGapPx`; it does not check the
  area stays inside the box for the moved position. Add that bound?
- Only `phone169` (667 x 375) is covered. The brief names this box; other sizes (`iphone`, `phone15`)
  are untested for these three behaviours.

## Suggestions

- `docs/code-health.md` line 333 (m165 b1 item) can close B-044's missing-test item once this lands.
  Not changed here (outside allow).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: pin that the mirror and place() ignore right-hand controls (B-044)

Adds three tests to hud_place_right_controls_test.dart: a control over the
board's centre leaves the mirror's rect and scale unchanged, place() gives
the same origin and scale around a mirror fit, and the clock area moves
clear of a control over its spot. No lib change; the behaviour already holds
on the base, so the tests pin it.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m165 c4 (B-044): done — test pins that place() and the mirror fit ignore hudRects and the clock area clears a control over its spot (6/6 pass in hud_place_right_controls_test); open: only phone169 covered, no bound check on the moved area.

## Delete

- none

## Self-check (review-rules part A; added by the driver after the wave 7 review)
1. Host setups: not affected; tests only. mirrorPlace returns null unless LayoutTarget.phones (camera.dart:241); the tests use the phones layout.
2. Kept state: none; the tests build their own camera and layout.
3. Combinations with pause, host away, Get ready, links, results: not tested; the camera's functions do not see them.
4. Folder and allow: the test file and this report only.
5. Stop: none needed.
6. Looks: no look involved (geometry only); box 667x375 only.
