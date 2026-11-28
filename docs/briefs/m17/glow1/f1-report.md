# glow1 f1: pin the golden glow's two handovers

## Summary

Tests only. No lib file changed, no settings.dart, no existing test changed. Both new files pass under `tools/mine.sh`
(6 tests in total: 3 + 3).

Files changed:
- `packages/puzzle_game/test/golden_match_snapshot_test.dart` (new): 3 tests for `Match.snapshot().golden`.
- `packages/puzzle_game/test/golden_match_painter_test.dart` (new): 3 tests for `MatchPainter`'s golden handover.

Checks run:
- `tools/mine.sh`: OK, 6 tests, format ran on 2 files, analyze on 1 package, no findings printed.

Test values (the expectations, as written):
- Snapshot, glow: `drive(m, idle, frames: 210)` (10.5 s at dt 0.05). `snapshot().golden` is non-null and equals `m.golden`.
- Snapshot, before delay: `drive(m, idle, frames: 190)` (9.5 s). `snapshot().golden` is null (firstDelayS is 10 s).
- Snapshot, after claim: at 210 frames, `place(m, left, 'p1', m.golden)`. `snapshot().golden` is null afterwards.
- Painter, split: `tree` puzzle, both boards empty, `seed: 1`, `golden: 0` vs `golden: null`, window 640 x 360, box 640 x 360.
  The left half (x 0..319) and the right half (x 320..639) each contain at least one differing RGBA byte.
- Painter, repaint: `MatchPainter` with `golden: 0` vs `golden: null` (distinct snapshot objects): `shouldRepaint` is true.

Decisions:
- The painter pixel check compares whole half-frames, not the target's own slot rectangle. Mapping target coordinates
  to frame pixels needs the field scale and offset of both `SplitLayout` boxes, and `pieceMean` in
  `test/support/piece_colours.dart` only handles the single-board `boardRect`. No support file is in `allow:`, so I
  did not add a helper. With only target 0 glowing, any difference in a half comes from that glow. It cannot prove the
  exact slot.
- `shouldRepaint` is true for any new snapshot object, because `MatchPainter.shouldRepaint` checks `identical(old.s, s)`
  first. The test therefore shows the golden handover only through that route. A stronger check would need a
  same-golden case that is not identical, and that case would return true anyway.
- The farthest-target trick was not needed: the half-frame check has no neighbour to disturb.

## Hand-over

- Both files are in `allow:`. Nothing was staged or committed.
- Nothing was deleted.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test(puzzle_game): pin the golden slot's handover to the snapshot and the painter

Two new test files cover the two handovers of the golden glow (M17 glow1).
Match.snapshot() carries the glowing slot after 10 s, not before, and not once
it is claimed. MatchPainter draws the glow on both split-board halves and
repaints when only the snapshot's golden slot changes. No lib change: the
lib already behaves as pinned.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

glow1 f1: the golden glow's snapshot and painter handovers are pinned by 6 tests (done). Open: the painter test checks whole half-frames, not the target's own slot rectangle, and needs a target-to-pixel helper to narrow it.

## Delete

- none
