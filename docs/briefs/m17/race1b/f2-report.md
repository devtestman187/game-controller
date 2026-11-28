# race1b f2: the present on the phone path, pinned by tests

## Summary

- The phone path draws the present. `_phones` (match_painter.dart:193) passes `present: s.present` to the board it draws, and the test below shows the box and its fuse reach the phone's shown board at all three sizes.
- No lib change. The only lib edit was the temporary removal of `present: s.present,` at match_painter.dart:193 to prove the test fails; it is restored, and `git diff -- packages/puzzle_game/lib` is empty.
- New file `packages/puzzle_game/test/present_phone_test.dart`: 6 tests, all passing (`tools/mine.sh`: "OK 6 tests packages/puzzle_game").
- Test shape: `MatchView` with `target: LayoutTarget.phones`, a 2-board race frame (all pieces in the tray), `PresentState` held by one side with fuse 20000 of 20000 (drawn at rest), `sunny` look, `capture` from `support/frames.dart`.
- For each size, two tests:
  - Camera shows the holder's side: the frame with the present differs from the frame without it in more than 0 pixels.
  - Camera shows the other side: the frame with the present differs in exactly 0 pixels.
- Sizes: `iphone` (852x393, from mirror_helpers), `Size(390, 844)` (portrait, literal), `phone169` (667x375, from mirror_helpers).
- Mutation check: with `present: s.present` removed at match_painter.dart:193, the three "shows the left side draws a present" tests FAIL (the "shows the right side" tests pass, as they should: they check for no change). Restored afterwards; `mine.sh` green again.
- Pixel values: the test counts changed pixels with a per-pixel RGB comparison over the whole frame; the exact counts were not printed, only the `> 0` and `== 0` results were checked.

## Decisions

- Used the helper sizes `iphone` and `phone169` as named in the brief, and added the portrait `Size(390, 844)` literal, because the brief said "about 390x844" but mirror_helpers has no portrait size. Its `iphone` constant is 852x393 (landscape), not 390x844.
- Reused the `board` and `frame` helpers from present_wiring_test.dart by copying them (they are not exported from a support file).
- Used `sunny` only; the second look is not tested here.
- Used `capture` directly on `MatchView` rather than `MatchPainter` so the phones path is the same one the app takes; `hud_rects_plumbing_test.dart` builds `MatchPainter` directly.

## Self-check (review-rules part A)

1. Host setups: the phones target only (a phone on "Show on this device" / joined phone). TV and PC setups are not covered by this job.
2. Kept state: none in this job; the present is a snapshot field.
3. Combinations (pause, host away, "Get ready", results, leaving): not covered by this job.
4. Stayed in `allow:`; only the two lib/test files named, plus this report.
5. No overstep: the phone path draws the present, so no bug to report to the driver.
6. Looks: `sunny` only; the menu look is not covered by this job.

## Checks

- `tools/mine.sh` (format, analyze, touched tests): OK 6 tests packages/puzzle_game, RESULT ok.
- `tools/mine.sh` with `present: s.present` removed: 3 FAILED (the left-side tests at all three sizes).
- `tools/mine.sh` after restoring: OK 6 tests, RESULT ok.
- `dart analyze` on the two changed files: No issues found.

## Hand-over

- Files changed: `packages/puzzle_game/test/present_phone_test.dart` (new), `docs/briefs/m17/race1b/f2-report.md` (this report).
- `packages/puzzle_game/lib/src/match_painter.dart`: edited and restored, net no change.
- Nothing staged; no git command that changes state was run.

## Questions

1. The brief's portrait size "about 390x844" does not match `iphone` in mirror_helpers (852x393). Should the portrait case use a named constant in mirror_helpers instead of the literal here?
2. The brief says "the other side" for the second camera; this test checks the held-by-left present against the right-side camera. If the intent was the reverse as well (held by right, shown left), that is a separate pair of tests.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: pin the present on the phone path at three phone sizes

A phone draws one side's board through its camera, and the present must
reach that board. Nothing tested the phones path, so a change that dropped
`present: s.present` in _phones would draw no box and no test would fail.
present_phone_test.dart draws a race held by the left side on a phone at
852x393, 390x844 and 667x375: the shown side changes, the other side is
unchanged. Removing the line fails the three shown-side tests. No lib change.

## Status row

race1b f2: phone-path present pinned (6 tests, 3 sizes, mutation-checked); no lib change. Open: TV/PC and the second look are not covered by this job; the 390x844 literal should move to mirror_helpers.

## Delete

- none
