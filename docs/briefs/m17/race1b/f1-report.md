# race1b f1: the present drawn from the board painter

Status: done. The present (`PresentState`) is now passed down from the match snapshot to each board's `PuzzlePainter`, which calls `paintPresent` once. `paintPresent` already skips a board whose side isn't the holder, so only the holding side's board shows it.

## Files changed

- `packages/puzzle_game/lib/src/view.dart`: imports `present.dart` and `present_painter.dart` (alphabetical, after `points.dart`).
- `packages/puzzle_game/lib/src/puzzle_painter.dart`: new `present` ctor parameter and `final PresentState? present` field (dartdoc'd, after `cat`); one call after the cat block: `if (present case final p?) paintPresent(canvas, p, field: field, look: look, side: s.side ?? PuzzleSide.left);`.
- `packages/puzzle_game/lib/src/match_painter.dart`: `present: s.present` at both `PuzzlePainter` sites (the split screen's board loop and the phones' board loop).
- `packages/puzzle_game/lib/src/match_view.dart`: `present: snapshot.present` at the match's `PuzzlePainter` site (the match snapshot is in scope there; the one-board branch now passes it too).
- `packages/puzzle_game/test/present_wiring_test.dart` (new, 3 tests, written first): a two-board race frame with a present held by the left side (and by the right side), rendered through `MatchView`, which draws a split match with `MatchPainter`. Each test counts the changed pixels against the same frame without the present, split into the left and right halves of the 640x360 window.

Not changed: `present_painter.dart`, `view.dart`'s single-board `PuzzleView` (per the brief), `cat_paint_test.dart`, `match.dart`, rules, the mirror painter.

## Checks

- `tools/mine.sh` before the wiring: the two "held by" tests FAILED (the pixel count on the holder's half was 0, as the call did not exist yet); the "no present" test passed. The first run also failed on the missing `seed` (a split match needs one), which I fixed in the test before the real run.
- `tools/mine.sh` after the wiring: `OK 15 tests packages/puzzle_game`, format and analyze clean, `RESULT: ok`.
- The expectations are "greater than 0" on the holder's half and exactly 0 on the other half, and 0 for a frame with no present. I did not record the exact pixel counts; no other value was computed for an expectation.

## Questions and suggestions

1. The one-board `PuzzleView` (view.dart) still builds its `PuzzlePainter` without a present, as the brief said. A race drawn through `PuzzleView` will not show the present; the match screens do. Should `PuzzleView` take a present too?
2. The phone path (`_phones` in match_painter.dart) passes `present` but no test covers it: the test uses the split screen only. A phone test at the phone size would close that.
3. Each test name states its rule; the wiring is covered at one window size only (640x360), not at a phone size.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

M17 f1: draw the present on the board that holds it

Passes the match snapshot's present down to each PuzzlePainter, which calls
paintPresent once. paintPresent skips boards that are not the holder's, so
only the holding side's board shows the gift box and its fuse. The
single-board PuzzleView still passes no present. The new test draws a race
through MatchView and counts changed pixels on each half of the window.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- race1b f1: the present is drawn on the holding side's board (split and phones via MatchPainter; MatchView). Open: the single-board PuzzleView does not pass it; no phone-size test yet.

## Delete

- none
