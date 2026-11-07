# M12 step 7 s7a2 — G4 report: `game.dart` 732 → 365

The four moves are in. `game.dart` is 365 lines, under the 400 hard limit. Two things differ from the plan, both
forced by the language and both reported below: `PuzzlePlayer` stays in `game.dart` (its private fields are used by
`update` and by both member groups, and private means library-private), and four lines that name `PuzzleGame`'s
statics inside the extensions gained a `PuzzleGame.` prefix (an extension may not use the extended type's static
members unqualified). No test was added, removed or edited.

## The four moves

| moved | from `game.dart` | to | lines moved | added lines |
| --- | --- | --- | --- | --- |
| `PieceState`, `PuzzleEventKind`, `PuzzleEvent`, `PieceRuntime`, `PuzzleResult`, `PuzzlePhase` | 11–123, minus `PuzzlePlayer` 74–107 | `lib/src/puzzle_values.dart` (new, plain file) | 79 | `import 'dart:ui';` + blank |
| `startAngles`, `compactStartAngles` | 665–730 | `lib/src/start_angles.dart` (new, plain file) | 66 | `import 'dart:math';`, `import 'puzzle.dart';` + 2 blanks |
| `_teamCarried`, `_move`, `_inField`, `_carryBig`, `_turn` | 410–488 | `lib/src/puzzle_carry.dart` (new part) | 79 | `part of 'game.dart';`, blank, `extension _PuzzleCarry on PuzzleGame {`, `}` |
| `_pickUp`, `_drop`, `_letGo`, `_putEverythingDown`, `_putDown`, `_matchingTarget`, `_nearestFreeTarget`, `_round` | 490–631 and 732 | `lib/src/puzzle_drop.dart` (new part) | 143 | `part of 'game.dart';`, blank, `extension _PuzzleDrop on PuzzleGame {`, `}`, blank |

`_round` stays a top-level function, after the extension at the end of `puzzle_drop.dart`, as arena_snapshot.dart
puts `_r`/`_rect` beside its extension. `game.dart` gains on top of that `import 'puzzle_values.dart';`,
`import 'start_angles.dart';` and the two `part` directives (4 lines).

Every moved range has exactly its planned length (79 + 66 + 79 + 142 + 1 = 367 lines left `game.dart`; the diff
says 371 removed / 4 added because the old import block was rewritten). Every member kept its text and its two-space
indentation; only the four static references below changed.

### What did not move, and why

- **`PuzzlePlayer` (old 74–107, 34 lines) stays in `game.dart`.** Five of its fields are private (`_aDown`,
  `_holdS`, `_grab`, `_lastTurn`, `_helpS`) and are read or written outside the class: by `update`
  (`game.dart:253-254`, `295`, `299`, `305`) and by both member groups (`puzzle_carry.dart:39`, `45-47`, `79-80`;
  `puzzle_drop.dart:41-44`). Private is library-private, so `PuzzlePlayer` has to sit in the same library as both
  parts — `puzzle_values.dart` is a separate library, and a part of `game.dart` can't be exported. Moving it would
  need public accessors (not a pure move) or make the type public API it doesn't need. It now sits at the top of
  `game.dart`, before `PuzzleGame`.
- **Four lines are prefixed with `PuzzleGame.`** inside the extensions: `speed` (`puzzle_carry.dart:37`),
  `dotRadius` (`puzzle_carry.dart:39`, `puzzle_drop.dart:14`) and `stickTurnFactor` (`puzzle_carry.dart:73`). An
  extension can't use the extended type's static members unqualified (analyze:
  `unqualified_reference_to_static_member_of_extended_type`); a mixin would hit the same rule. The rest of each line
  is unchanged.

## Imports and exports

- `game.dart`: + `puzzle_values.dart`, + `start_angles.dart`, + `part 'puzzle_carry.dart';`,
  `part 'puzzle_drop.dart';`.
- `match.dart`, `view.dart`: + `import 'puzzle_values.dart';` (both still use `PuzzleGame`/`PuzzlePlayer`).
- `snapshot.dart`, `puzzle_events.dart`: `import 'game.dart';` → `import 'puzzle_values.dart';` — the value types
  were the only thing they used from `game.dart`.
- `split_layout.dart`: `import 'game.dart';` → `import 'start_angles.dart';` (it used only `compactStartAngles`).
- `puzzle_game.dart`: + `export 'src/puzzle_values.dart';`, + `export 'src/start_angles.dart';`, so every public name
  stays where callers import it from.

The two parts pick up `game.dart`'s imports, so `connection` (`GamepadState`, `GamepadButton`, `InputMode`),
`dart:ui` (`Offset`), `puzzle.dart` (`angleError`, `snapAngle`), `puzzle_values.dart`, `settings.dart` and `tray.dart`
are all in scope there without new directives.

## Line counts

| file | lines | |
| --- | --- | --- |
| `lib/src/game.dart` | 365 | touched, 732 before; **flagged: over 300** (aim; under the 400 limit) |
| `lib/src/puzzle_values.dart` | 81 | new |
| `lib/src/puzzle_carry.dart` | 83 | new |
| `lib/src/puzzle_drop.dart` | 148 | new |
| `lib/src/start_angles.dart` | 70 | new |
| `lib/puzzle_game.dart` | 21 | touched, 19 before (+2 exports) |
| `lib/src/match.dart` | 199 | touched, 198 before (+1 import) |
| `lib/src/snapshot.dart` | 254 | touched, 254 before (1 import swapped) |
| `lib/src/puzzle_events.dart` | 68 | touched, 68 before (1 import swapped) |
| `lib/src/split_layout.dart` | 232 | touched, 232 before (1 import swapped) |
| `lib/src/view.dart` | 65 | touched, 64 before (+1 import) |

No lib file I created or touched is over 400. `puzzle_values.dart` (81) is smaller than the plan's 113 because
`PuzzlePlayer` stayed behind.

## Checks

- `tools/check.sh format analyze puzzle host` — **PASS** all four: format (1s), analyze (7s), puzzle (80 tests, 16s),
  host (60 tests, 67s).
- `tools/review.sh --strings` — `strings: 0 removed, 0 added, 72 unchanged or moved`. The lines this diff adds that
  are not moved text are the directives (4 in `game.dart`, 6 in the new files, 1 import each in the five lib files,
  2 exports in `puzzle_game.dart`), the four wrapper lines (`extension _PuzzleCarry on PuzzleGame {` and `}`, and
  `extension _PuzzleDrop on PuzzleGame {` and `}`) and one blank line: none of them holds a literal, so 0/0.
- `tools/review.sh` — **2 fail, 13 note**. Neither FAIL is on a line this diff adds; both are long functions that
  were already there, and `review.sh` measures every member of every file a diff touches:
  - `game.dart:231` `List<PuzzleEvent> update(…)` **103 lines** (>60). Text unchanged: it was 106 lines at `HEAD`
    (303–408, signature to closing brace = 103 by the script's count).
  - `split_layout.dart:92` `static SplitLayout _compute(…)` **120 lines** (>60). Text unchanged; the file is only in
    the diff because its import line changed.
  Notes: `size game.dart 365` (aim 300) · `func game.dart:151` `_trayLayout` 54 lines · `func puzzle_drop.dart:4`
  `_pickUp` 51 lines · `number puzzle_drop.dart:148` `100` (in `_round`) · nine `number` notes in
  `start_angles.dart` (50, 360, 30, 360, 360, 30, 1.1, 90, 360 — the moved literals).

## Test counts

- `packages/puzzle_game`: **80 tests, all pass**, the same 80 as before (match 17 + split_layout 7 + tray_pile 4 +
  tray_packing 3 + rules 24 + view 7 + snapshot_lerp 7 + session 7 + module 3 + frame_size 1). No file under
  `test/` was touched.
- `packages/party_host`: **60 tests, all pass**. The brief says 57; no `party_host` file is in this diff, so 60 is
  `HEAD`'s count (question 3).

## Questions

1. **`PuzzlePlayer` stays in `game.dart`** — the plan put old 74–107 in `puzzle_values.dart`, but its private fields
   are used by `update` and by both extension groups, which are in `game.dart`'s library. Do you want it to stay
   (my recommendation: yes, it is the only pure-move option), or should a later job give it public accessors and
   move it out?
2. **The two `review.sh` FAILs** (`update` 103 lines, `SplitLayout._compute` 120 lines) are pre-existing and
   untouched by this diff, but the check fails on them. Clearing them means splitting both functions, which is code
   work, not a move — a cleanup job of its own. Say if you want that to be s7b's first slice.
3. **Host tests: 60, not the brief's 57.** Nothing in `packages/party_host` changed in this job, so the number is
   `HEAD`'s; either the brief's figure is stale or I'm counting a different set (the `PASS host` line says
   "60 tests").
4. **Four `PuzzleGame.` prefixes** on moved lines (`speed`, `dotRadius` ×2, `stickTurnFactor`): the language requires
   them inside an extension. Is that acceptable, or would you rather the extensions become a mixin (which needs the
   same prefixes, plus one line on the class)?

## Not sure about

- **Line endings.** The five new files are LF; this checkout is CRLF. Git normalises (`* text=auto`), so the commit's
  content is unchanged, but `git diff` may warn "LF will be replaced by CRLF" for them. s7a's new file had the same
  note.
- **No byte-for-byte proof of the moves.** The shell here blocks `awk`/`sed`/`md5sum` pipelines, so I could not
  checksum the moved ranges against `HEAD`. The evidence is: each range has exactly its planned line count, the
  four old files compile with no new import, `dart analyze` is clean, `--strings` is 0/0 and the 80 puzzle tests
  (which exercise all of `update`, the pick-up/drop rules and both start-angle functions) pass unchanged.
- **`puzzle_values.dart`'s name** now covers everything but `PuzzlePlayer`, which is still a value type. If it later
  grows public accessors, moving it there is the natural home.

## Commit message

```
refactor(puzzle): split game.dart into values, angles and two parts

game.dart 732 → 365: the piece/event/result enums and classes move to
puzzle_values.dart, startAngles and compactStartAngles to
start_angles.dart, and the two member groups to the puzzle_carry and
puzzle_drop parts, each wrapped in a private extension on PuzzleGame.
PuzzlePlayer stays in game.dart: update and both extensions use its
private fields. Four static references gain a PuzzleGame. prefix.
Pure moves: 80 puzzle and 60 host tests, review.sh --strings 0/0.
```

## Status row

| 7 Puzzle on phones | s7a2 done ([s7a2-report.md](s7a2-report.md)): `game.dart` 732 → 365, split into `puzzle_values.dart` (81) and `start_angles.dart` (70) plus the `puzzle_carry`/`puzzle_drop` parts (83, 148), the two groups wrapped in a private `extension … on PuzzleGame`; `PuzzlePlayer` stays in `game.dart` because `update` and both parts use its private fields. 80 puzzle and 60 host tests unchanged, `review.sh --strings` 0/0. Open: s7b (the `phones` world), and two pre-existing `review.sh` FAILs (`game.dart`'s `update` 103 lines, `SplitLayout._compute` 120 lines) |

## Delete

- none
