# Review of b012b-2-medium (read-only)

## Summary

`small fixes` — 1 must, 2 should, 2 could.

- **Must:** the six Medium renders in `docs/design/puzzles/` were never updated: `boat.png` (and its five
  neighbours) are byte-identical to the version from commit `1270b02`, so brief item 2 ("the PNGs under
  docs/design/puzzles/ update") is not delivered, though the report says the render test wrote them.
- **Should:** self-check 4 is not true of the tree I reviewed: three tracked files outside `allow:` are
  modified (`docs/design/m13-puzzles.png`, `m13-puzzles-night.png`, `m13-tablet-board.png`), and the report
  names only the first two.
- **Could:** `docs/PRD-v2.md:285` still says Medium has "About 6" pieces and "About half" turned.
- What holds: the new limits and messages, the six files' counts (boat 8/4, car 9/4, robot 9/5, train 9/5,
  castle 9/4, butterfly 8/6, one big each), `library_test` and the new `medium_limits_test` pass, format clean.

## Findings

- **must** docs/briefs/m14/bugs6/b012b-2-medium-report.md:115 "test/puzzle_render_test.dart wrote docs/design/puzzles/"
  does not hold in the delivered state: `docs/design/puzzles/{boat,car,robot,train,castle,butterfly}.png` are
  unchanged since `1270b02` (`git log -- docs/design/puzzles/boat.png`), so the design folder still shows the
  6–7-piece Medium pictures that `docs/levels.md:44` asks to commit with the level → run the puzzle suite (or
  `tools/level.sh render`) and commit the twelve 600 × 392 renders it writes (`puzzle_render_test.dart:124`).
- **should** docs/briefs/m14/bugs6/b012b-2-medium-report.md:47 self-check 4 says the puzzle suite's files
  outside `allow:` were "put back byte for byte", but `git status` in the delivered tree shows
  `docs/design/m13-puzzles.png`, `docs/design/m13-puzzles-night.png` and `docs/design/m13-tablet-board.png`
  modified, and the third file is mentioned nowhere in the report → name all three and either restore the third
  or commit the sheets as `docs/levels.md:186` asks.
- **should** docs/briefs/m14/bugs6/b012b-2-medium-report.md:3 the Summary never says what the owner should try
  on a device, which the brief asks for after "anything not done" → add one line (the boat on a phone: two
  differently coloured waves and the smaller opponent mirror).
- **could** docs/PRD-v2.md:285 the level table's Medium row ("About 6" pieces, "About half" turned) now
  contradicts `docs/levels.md`'s 8 to 10 / at least 4 → update the row; the PRD is outside this job's `allow:`,
  so it is a separate edit.
- **could** packages/puzzle_game/test/rules_test.dart:378 no test now asserts that a library puzzle has two
  pieces of one `kind` (the boat's waves lost `kind`; the car's, robot's and train's pairs are only reached
  through `checkLibrary`) → keep the count assertion and add one piece of one kind there.

## Decisions to confirm

- `packages/puzzle_game/test/mirror_place_test.dart:82` turns an equality into `lessThanOrEqualTo(fraction + 1e-9)`.
  The code does clamp to fit (`camera.dart:267`'s `_fitting` under `maxScale`), and the boat's 94.45 × 66.67 rect pins still fix the size, so
  nothing is lost today; but the "largest that fits beside the clock area" rule now has no test of its own, and
  the boat is the only puzzle that hits the clamp.
- The m13 sheets: `docs/levels.md:186` says to commit them with a puzzle; the job restored them instead and asks
  (question 1). One of the two has to give.
- Opponent mirror: the boat's mirror drops from 98.7 to 94.45 px (about 4%) on a phone. Visible in play; worth a
  device look with the rest.
- `packages/puzzle_game/test/frame_size_test.dart:31` now derives the count (`hasLength(puzzle.pieces.length)`)
  instead of pinning 8; the 2.5 KB budget still covers the bigger frame, so the report's "678 bytes" is a
  `debugPrint` value, not an assertion.

## Could not check

- The full puzzle suite (report: 433 tests) and `analyze`: not re-run — the suite rewrites `docs/design/*.png`
  outside this review's `allow:`. I ran `test/medium_limits_test.dart` and `test/library_test.dart` only (4 tests,
  PASS) and `dart format --output=none` over the five changed Dart files (0 changed).
- `tools/level.sh check` and `render`: the sandbox refuses to start the script, so I could not see its output.
- Host, phone and TV suites, and `controller_app/test/puzzle_size_test.dart`: not run.
- The other five picture pairs: I looked at the boat's `solved` and `start` PNGs only; whether each subject still
  reads as the old one is the owner's eye, not mine.
- The split/span figures in the report's table (0.99–1.18, 53–78% × 49–72%) are not pinned by any test I read.

## Commit message

```
B-012b phase 2 review: the design renders are missing

Review of b012b-2-medium: the Medium limits (8-10 pieces, at least 4
turned, 1 or 2 big, one repeated pair) and the six redone pictures pass
the library check and the new medium_limits_test, so the code side is
small fixes away.

Must: docs/design/puzzles/ still holds the old 6-7-piece Medium renders,
though the report says the render test wrote them. Should: three design
sheets are left dirty outside allow:, one of them unnamed. Could: the
PRD's Medium row is stale and the report omits what to try on a device.
```

## Status row

`- B-012b phase 2 reviewed: limits, pictures and tests hold; open — the six docs/design/puzzles renders were never committed, three design sheets are dirty and the PRD's Medium row is stale.`

## Delete

- none
