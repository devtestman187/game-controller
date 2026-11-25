# n9sr report: Shape Race HUD says the night's "Round N of M"

## Summary

What changed: the one-board HUD (the screen path of `MatchView`, which draws `PuzzlePainter` with the HUD on) now draws
"Round N of M · <name>" on board 0, with the name cut by an ellipsis short of the clock's pill. Outside a night, or with no
round named, the HUD is unchanged.

Tests: `tools/mine.sh` before the change: FAILED (test file did not compile: `roundLabel` not a parameter). After the
change: OK, 18 tests run in packages/puzzle_game (the touched-test run), format and analyze clean. The new file is
`packages/puzzle_game/test/round_label_test.dart` and holds 12 of those tests (3 checks x 2 looks x 2 sizes); I did not
break down the other 6.

The HUD check is pixel based, as `points_paint_test` does it. I did not print the measured values (no debug output was
added), so the expectations are thresholds only: changed pixels > 20 for the label, and rightmost changed column <
width / 2 (320 px at 640 wide, 180 px at 360 wide), which keeps the label left of the centred clock.

Decisions:
- The label is a separate `_labelledName` in board_hud.dart, not a change to `_text`: `text_paint.dart` is not in allow:,
  and `_layout` has no max width or ellipsis.
- The ellipsis cap is only applied when a label is present, so names without a label draw exactly as before.
- `PuzzlePlayView` builds the label (`_roundLabel`), returns null unless both `round` and `rounds` are set.
- `_nameGap` is 1.0 world unit; the room is measured to the clock's pill and the field's centre, not to the count.
- I dropped a planned "no label draws nothing" test: as written it compared two identical calls. The pinned picture tests
  (points_paint_test, portrait_hud_test, match tests) stayed green, which covers the no-label path.

## Files changed

- `packages/puzzle_game/lib/src/board_hud.dart`: `_nameGap`; the label branch in `_hud`; `_labelledName` (ellipsis cut).
- `packages/puzzle_game/lib/src/puzzle_painter.dart`: optional `String? roundLabel` (doc, constructor, shouldRepaint).
- `packages/puzzle_game/lib/src/play_view.dart`: `_roundLabel` getter; passed to `MatchView`.
- `packages/puzzle_game/lib/src/match_view.dart`: optional `roundLabel` (doc, constructor); passed to the one-board
  `PuzzlePainter` only.
- `packages/puzzle_game/test/round_label_test.dart` (new): menu and TV looks at 640 x 360 and 360 x 640; label drawn;
  long label cut left of the clock; with two boards only board 0 draws it.

Not changed, on purpose: `view.dart` (`PuzzleView` is not in the play path; only tests build it, so a parameter there
would be unused), `match_painter.dart` (see question 1), `portrait_hud_test.dart` (nothing pinned broke).

## Self-check (review-rules part A)

1. Host setups: the label shows only on the one-board screen path (`PuzzlePainter` with HUD on). Tested by
   round_label_test (painter level). Split and phone paths: not shown; see question 1.
2. Kept state: none added. The label is a value passed in per frame; nothing starts or ends.
3. Combinations: the label repaints when it changes (`shouldRepaint`). Pause, host away, "Get ready", dropped link and
   results do not touch it; not tested at view level.
4. Folder and allow:: stayed inside allow:. Files touched are all listed above.
5. Stops: question 1 is the one place the brief's wording does not reach the drawing code.
6. Looks: menu (Sunny, tv off) and TV (Sunny, tv on), at two sizes; no fixed pixel heights.

## Questions

1. Where should the round label show? In a two-board split or a phones target, `MatchPainter` draws each board with the
   HUD off (`hud: false`), and its strip and phone HUD (`match_hud.dart`, `phone_hud.dart`) draw the clock and counts but
   no puzzle name. So "Round N of M" does not appear there, and passing the label into `MatchPainter` would give a
   parameter nothing draws. Needs a decision: add the label to the strip and phone HUD (outside allow:), or accept that
   only the one-board screen shows it. Note: a one-board round on a phones target also goes through `MatchPainter`, so it
   shows no label either.
2. `view.dart`'s `PuzzleView` was in the brief's list but is not in the play path. Confirm it should stay unchanged.
3. Churn: `tools/mine.sh` printed "churn: reverted 3 generated file(s)". At the start, `tv_test_app/windows/flutter/`
   `generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake` were modified in the
   working tree; they are now clean. I did not revert them by hand (git writes are not allowed to me), but the script's
   churn step did. If those edits mattered, they must be restored by hand.

## Suggestions

- A device check of the cut label on the TV and on a narrow phone, since the tests only prove it stays left of the clock.
- If question 1 goes to the strip, the same `_labelledName` cap can be reused there.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

puzzle HUD: a night's round shows as "Round N of M" before the name

The one-board HUD draws the round label on board 0, before the puzzle name,
and cuts the name with an ellipsis short of the clock so the label never
pushes the clock. Outside a night the HUD is unchanged. Split and phone
HUDs do not draw names yet, so the label does not show there (owner decision).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave2-789 n9sr: one-board Shape Race HUD draws "Round N of M · name" in a night (round_label_test); open: split and phone HUDs show no label (owner to decide), PuzzleView not wired.

## Delete

- none
