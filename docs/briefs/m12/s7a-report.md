# M12 step 7 s7a — G4 report: the splits of `view.dart` and `match_test.dart`

**Not complete: two of the three splits are done, `game.dart` is not touched.** Its two member-group parts
(`puzzle_carry.dart`, `puzzle_drop.dart`) cannot be done as pure moves: a Dart `part` file can hold only top-level
declarations, never the members of a class declared in the library, so those 222 lines cannot leave `PuzzleGame`
without adding `extension … on PuzzleGame {` (or a mixin) around them. That is a line that is not a directive, and
the brief says to stop instead. I stopped there and left `game.dart` alone at 732 lines, so the file is still over
the 400 hard limit. The whole of it is still to do; see *Questions* for the three ways to finish it.

## What was done

Plan §1 for `view.dart` and for `match_test.dart`, as pure moves: only `part`, `part of` and `import` lines were
added or removed, every other line is byte-identical (checked with md5 of the moved ranges against `HEAD`).

### `view.dart` 439 → 64

- `lib/src/view.dart` keeps imports 1–9, `PuzzleView` 11–30, `MatchView` 32–50, `fieldIn` 52–58 and the two
  colours 60–61, and gains `part 'match_painter.dart';` and `part 'puzzle_painter.dart';` after the imports.
- `lib/src/match_painter.dart` (new part): old 63–182, `MatchPainter` (120 lines) with its doc comment.
- `lib/src/puzzle_painter.dart` (new part): old 184–415, `PuzzlePainter` (232 lines), plus the top-level `_text`
  old 417–439 (23 lines); the blank line that separated them (old 416) came with them.

### `match_test.dart` 1074 → 435

Helpers at `test/support/match_helpers.dart`, as Claude approved for Q9 (the `game_kit` convention):

- `test/support/match_helpers.dart` (new, not a test): old 9–131 — `load`, the four `GamepadState` consts,
  `begin`, `drive`, `tap`, `tapAGame`, `place`, `onePiece`, `crateAndBall`, `twoSquares`, `scaledBounds`,
  `pieceBox`, `rows`, `visibleFraction`. Imports `dart:io`, `dart:math`, `dart:ui show Offset, Rect`,
  `connection`, `puzzle_game` (no `flutter_test`: nothing here uses a matcher).
- `test/tray_packing_test.dart` (new): groups `compact start angles` and `tray packing`, old 215–324.
- `test/tray_pile_test.dart` (new): groups `tray pile` and `tray size in play`, old 542–728.
- `test/split_layout_test.dart` (new): group `split layout`, old 325–541. s7b's `phones` cases go here.
- `test/match_test.dart` keeps `formats` (134–213), `sides` (729–839), `big pieces` (841–1012) and `snapshots`
  (1014–1073); its imports drop `dart:io`, `dart:ui`, `connection` (nothing left uses them) and gain
  `import 'support/match_helpers.dart';`.

### `game.dart` — not started

Old line ranges for the next job: `puzzle_values.dart` 11–123, `start_angles.dart` 665–730, `part
'puzzle_carry.dart'` 410–488, `part 'puzzle_drop.dart'` 490–631 plus `_round` 732. The first two are pure moves and
can be done as written; the two parts need one added line each (see *Questions*).

## Line counts (new and touched)

| file | lines | |
| --- | --- | --- |
| `lib/src/view.dart` | 64 | touched, 439 before |
| `lib/src/match_painter.dart` | 122 | new |
| `lib/src/puzzle_painter.dart` | 258 | new, **flagged: over 300** (within the 400 limit) |
| `lib/src/game.dart` | 732 | **not touched**, over the 400 limit — the part of the job that is blocked |
| `test/match_test.dart` | 435 | touched, 1074 before; **flagged: over 300** (test limit 500) |
| `test/split_layout_test.dart` | 225 | new |
| `test/tray_packing_test.dart` | 119 | new |
| `test/tray_pile_test.dart` | 195 | new |
| `test/support/match_helpers.dart` | 130 | new |

No lib file among those I changed is over 400 and no test file is over 500.

## Test counts

Before (`flutter test` in `packages/puzzle_game`, 80 tests):

| file | tests |
| --- | --- |
| `match_test.dart` | 31 (formats 3, compact start angles 2, tray packing 1, split layout 7, tray pile 3, tray size in play 1, sides 6, big pieces 6, snapshots 2) |
| `rules_test.dart` | 24 |
| `view_test.dart` | 7 |
| `snapshot_lerp_test.dart` | 7 |
| `puzzle_session_test.dart` | 7 |
| `puzzle_module_test.dart` | 3 |
| `frame_size_test.dart` | 1 |
| **total** | **80** |

After (80 tests, all pass):

| file | tests |
| --- | --- |
| `match_test.dart` | 17 (formats 3, sides 6, big pieces 6, snapshots 2) |
| `split_layout_test.dart` | 7 |
| `tray_pile_test.dart` | 4 (tray pile 3, tray size in play 1) |
| `tray_packing_test.dart` | 3 (compact start angles 2, tray packing 1) |
| `rules_test.dart` | 24 |
| `view_test.dart` | 7 |
| `snapshot_lerp_test.dart` | 7 |
| `puzzle_session_test.dart` | 7 |
| `puzzle_module_test.dart` | 3 |
| `frame_size_test.dart` | 1 |
| **total** | **80** |

The four files that came from `match_test.dart` hold 17 + 7 + 4 + 3 = 31 tests, the same 31 as before; no test was
added, removed, renamed or edited.

## Checks

- `tools/check.sh format analyze puzzle host` — **PASS** all four: format (1s), analyze (10s), puzzle (80 tests,
  11s), host (57 tests, 77s).
- `tools/review.sh --strings` — `strings: 0 removed, 0 added, 12 unchanged or moved`. The only strings added in
  `lib/` are the directive lines (`part 'match_painter.dart';`, `part 'puzzle_painter.dart';`, and the two
  `part of 'view.dart';`), which the check skips by design; every literal of the painters is counted as moved.
- `tools/review.sh` — `review: 0 fail, 29 note`. Every note is a `number` note on a moved painter literal
  (`0.4`, `3.2`, `Colors` alphas, …): the same literals scored the same in `view.dart` before the move.

## Questions

1. **The `game.dart` parts need one non-directive line each.** A part cannot add members to a class: the class in
   `game.dart` would have to stay open across the parts, and Dart has no partial classes. Three ways to finish it:
   (a) wrap each group in `extension _PuzzleCarry on PuzzleGame { … }` / `extension _PuzzleDrop on PuzzleGame { … }`
   inside the parts — 2 added lines per part (the name and the closing brace), every moved line unchanged, private
   members still reachable because the extension is in the same library; (b) the same but as `mixin _PuzzleCarry on
   PuzzleGame`, which also adds one line to the class (`with _PuzzleCarry, _PuzzleDrop`); (c) plain files, which
   needs a public API (getters for `pieces`, `_players`, `_filled`, `_nextLayer`) and is not a pure move. My vote is
   (a): it is the smallest change and keeps the move mechanical. Which do you want?
2. **Should the two pure-move pieces of `game.dart` (`puzzle_values.dart` 11–123 and `start_angles.dart` 665–730) be
   done now?** I left them undone so that `game.dart` is untouched: doing them alone would leave it at about 550
   lines, still over the 400 limit, which the job's own rule calls a failure. Say the word and they can go in the
   same job as the parts.

## Not sure about

- The rebuilt `match_test.dart` was written with LF line endings; the rest of the checkout is CRLF (`* text=auto`,
  Git on this PC checks out CRLF). Git normalises, so the commit's content is unchanged, but `git diff` prints
  "LF will be replaced by CRLF the next time Git touches it" for that file.
- `puzzle_painter.dart` is 258 lines in one part, which is what the plan's ranges give; it is the largest of the
  three new lib files but still under both limits.
- `test/support/` follows the `game_kit` convention (`test/support/fake_game.dart`): no `_test` suffix, so the
  runner does not treat it as a suite.
- The working tree was already dirty when I started, and I did not touch either: `docs/briefs/m12/STATUS.md` carries
  the s6/s7 rows from an earlier job, and `tv_test_app/windows/flutter/generated_plugin_registrant.*` and
  `generated_plugins.cmake` show as modified only in their line endings (their content diff is empty).

## Commit message

```
refactor(puzzle): move the painters and the match tests into files

view.dart 439 → 64: MatchPainter and PuzzlePainter with their shared
_text move into the match_painter and puzzle_painter parts, joined by
two part directives; view.dart keeps the two views, fieldIn and the
colours. match_test.dart 1074 → 435: the shared helpers move to
test/support/match_helpers.dart (the game_kit convention), and the
groups go to tray_packing_test, tray_pile_test and split_layout_test.
Pure moves: same 31 tests in the four match files, 80 in the package,
tools/review.sh --strings 0/0. game.dart's split is open.
```

## Status row

| 7 Puzzle on phones | s7a partly done ([s7a-report.md](s7a-report.md)): `view.dart` split into the `match_painter`/`puzzle_painter` parts (439 → 64) and `match_test.dart` into `test/support/match_helpers.dart` plus `split_layout_test`, `tray_packing_test` and `tray_pile_test` (1074 → 435, still 31 tests). Open: the `game.dart` split — its two member-group parts need one non-directive line each (a part can't hold class members), so it waits on Claude's choice between an `extension on PuzzleGame` wrapper, a `mixin`, or plain files with a public API |

## Delete

- none
