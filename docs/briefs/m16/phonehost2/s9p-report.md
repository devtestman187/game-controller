# S9p report — the tablet-board picture refreshed once

## Summary

`docs/design/m13-tablet-board.png` is refreshed to what today's code renders, using the guard S9a
added: `cd packages/puzzle_game && flutter test --dart-define=UPDATE_PNG=true test/tablet_board_png_test.dart`
passed (1 test) and rewrote the file. Sizes: **before 126,808 bytes, after 167,512 bytes** — the same
167,512 the m16 phonefit review measured, so the committed picture was the stale one, not the render.
The new file is a valid PNG (`file`: PNG image data, 2486 x 1414, 8-bit/color RGBA, non-interlaced;
2486 = 2 × 24 margin + 1366 landscape + 48 gap + 1024 portrait, 1414 = 2 × 24 + 1366, as the test's
layout computes), sha256 `4cd46f7e6ae832fe560543918316b3a7fb0e59708e1281f39ba7b77855a04e40`.

Then the same test once without the define:
`flutter test test/tablet_board_png_test.dart` — passed (1 test), and the picture was left alone:
still 167,512 bytes, the same sha256 and the same mtime (23:05) before and after.

`git status --short docs/design` printed exactly one line, ` M docs/design/m13-tablet-board.png`, after
both runs: no other picture in `docs/design/` was rewritten or staged. No Dart file changed — the
brief exempts this job from tests-first because it is a picture refresh only.

`tools/check.sh format` — PASS (8s).

## Hand-over

- The picture now matches the code at this commit; if a later job changes the joined board's look
  (the phone_fit matrix work in S9, or `MatchView`'s pad rects), it will go stale again and needs
  another `UPDATE_PNG=true` run plus a commit.
- Left alone, outside this job's `allow:`: the other picture tests still write their PNGs on every
  run (`cat_pictures_test`, `puzzles_png_test`, `placed_look_png_test`, `portrait_hud_png_test`,
  `mirror_png_test`, `worker_*_png_test`, `colour_swatches_test`, `puzzle_render_test`), and
  `docs/briefs/m16/STATUS.md` still lists the PNG guard as open work in its phonehost1 paragraph —
  both are S9a's hand-over, unchanged here.
- Not mine, left alone: `git status` also shows `tv_test_app/windows/flutter/generated_*` dirty
  (mtime 23:05, the checkout time, so they were dirty before this job). Nothing was staged.

## Self-check (review-rules.md part A, item 5)

5. **Stop rather than overstep** — Stopped after the refresh. Touched only
   `docs/design/m13-tablet-board.png` (through the guarded test run) and this report, both in
   `allow:`; no Dart file, no other picture, no STATUS.md, nothing staged. Check: `git status`.

## Commit message

```
Refresh the tablet-board picture to what the code renders

docs/design/m13-tablet-board.png was stale: 126,808 bytes against the
167,512 today's MatchView renders. The guarded test was run once with
--dart-define=UPDATE_PNG=true and rewrote it, and a plain run afterwards
passes and leaves it untouched. No code change: the picture refresh the
phonefit review asked for.
```

## Status row

S9p done: `docs/design/m13-tablet-board.png` refreshed to today's render (126,808 -> 167,512 bytes; plain test run leaves it untouched); open — S9's phone_fit matrix + TV check and the other unguarded PNG tests.

## Delete

- none
