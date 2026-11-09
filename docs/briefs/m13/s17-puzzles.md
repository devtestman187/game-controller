job: M13 device fixes 7: six Easy and six Medium puzzles, every piece easy to see on the board (owner, Nov 9, 2026: "More puzzles. Can we have 6 easy and 6 medium puzzles?" and "It's not easy to see if the rectangle in the rocket was placed. There's not much contrast between where to place the piece and the piece itself in some cases. We should aim for higher contrast so players know when the piece is down.")
pub: no
stop: after it.
read: packages/puzzle_game/puzzles/*.json and index.json · packages/puzzle_game/lib/src/puzzle.dart (the format: `rect`, `polygon`, `circle`, `big`, `rotated`, `at`, `level`, symmetry), library.dart, game.dart (the field and board sizes), tray.dart (how the tray lays pieces out), split_layout.dart · the puzzle tests in packages/puzzle_game/test · packages/toy_look/lib/src/toy_colors.dart (the board: Sunny `#FFEFD0`, Night `#30297A`; the toy palette) · docs/design/look-and-sound.md (D9: piece colours from the toy palette; Easy outlines in the piece's colour, Medium neutral) · docs/PRD-v2.md, the Shape Race levels and the acceptance line "Every puzzle on every level can be finished within 2 minutes by an adult, and the Easy ones by an 8-year-old after one practice round" · docs/review-rules.md · docs/coding-guidelines.md

Today: Easy has house, rocket and tree; Medium has boat. This job is the puzzle files only: another job changes how targets and placed pieces are drawn, so don't touch the painters.

Claude's rules:
1. **Twelve puzzles**: 6 Easy (house, rocket, tree, plus **sun**, **fish**, **snowman**) and 6 Medium (boat, plus **car**, **robot**, **train**, **castle**, **butterfly**). Each is a picture a child knows at a glance, made of the shapes the format has.
   - Easy: 4–5 pieces, mostly distinct shapes, few turned (`rotated`) pieces, no two pieces of the same shape and size.
   - Medium: 6–8 pieces, one or two big (team) pieces, some turned pieces, and at most one pair of pieces that share a shape (the existing boat is the model).
   - Every puzzle fits the board and its tray the way the existing four do (the tray tests and the split layout's must pass for each), and none is harder to finish than the boat (Medium) or the house (Easy) by more than a couple of pieces.
2. **Every piece is held by a point inside it.** The point a piece is held and turned by (its shape's origin) must be strictly inside the shape, not on an edge: the boat's sail and flag have it on their left side, which sent the worker off into empty space (owner's test of m13.3; Claude fixed the drawing). Re-centre the sail and flag on their centroid, moving their `at` so the picture is unchanged, and add a test that fails for any piece whose origin is on or outside its shape.
3. **Every piece stands out on the board**, in both looks. Measure each piece colour against the board (Sunny `#FFEFD0`, Night `#30297A`) as the OKLab distance. A piece must be at least **0.15** from the board in both looks; tell me in the report if 0.15 turns out wrong (flags pieces that read well, or passes ones that don't, like the rocket's light grey body, `#D5DBDB`), with the table that shows it. Recolour every failing piece from the toy palette, keeping the picture's meaning (a rocket body can be a stronger silver-blue; a snowman can't be white on cream, so give it a pale blue-grey that passes, or outline-led colours). Add the test.
4. Pieces in one puzzle are told apart by colour too: no two pieces of one puzzle within OKLab 0.08 of each other, unless they're the same shape (the house's walls and door must differ).
5. `index.json` lists them, Easy first then Medium, in the order above.
6. Design: add the twelve to the design doc (the levels section the PRD cites, or look-and-sound.md beside D9), with the two colour rules and the held-inside rule, "Decided at device test 3" (owner, Nov 9).

tests (each failing first):
- The library has 6 Easy and 6 Medium puzzles, the ids above.
- Every piece's origin is strictly inside its shape (fails today for the sail and the flag).
- Every piece is at least 0.15 OKLab from the board in Sunny and Night (fails today for at least the rocket's body).
- No two pieces of a puzzle within 0.08 of each other unless the same shape.
- Every puzzle lays out on the board and its tray, on one board and split, as the existing four do (extend the existing per-puzzle tests to all twelve).
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). The m12 mirror PNGs may change only if a recoloured piece is in them; say which.
- A picture, `docs/design/m13-puzzles.png`: every puzzle finished (all pieces locked), in a grid with its name and level, Sunny, and the same in Night as `m13-puzzles-night.png`. Deterministic.

in the report: test counts before and after; the files changed; a table of every piece's colour and its OKLab distance to both boards (before and after for the recoloured ones); for each new puzzle its pieces and why it fits its level.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/party_host, the painters or camera.dart (other jobs are working there) · the puzzle tests rewrite docs/design/m12-mirror-*.png: if they change, keep them and say why.
allow: docs/briefs/m13/s17-puzzles-report.md · docs/design · docs/PRD-v2.md · packages/puzzle_game/puzzles · packages/puzzle_game/test · packages/puzzle_game/lib/src/puzzle.dart · packages/puzzle_game/lib/src/library.dart
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s17-puzzles-report.md
