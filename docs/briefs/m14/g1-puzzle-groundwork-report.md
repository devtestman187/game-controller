# M14 g1: Shape Race groundwork — report

## Done

### 1. game.dart split (no behaviour change)

`game.dart` 399 → 279 lines. Two parts:

- `puzzle_player.dart` (new, 35): the `PuzzlePlayer` class, verbatim. It has no `PuzzleGame` receiver, so an
  extension cannot hold it — it has to be a part or a separate library, and a part keeps the field private.
- `puzzle_tick.dart` (new, 111): `extension _PuzzleTick on PuzzleGame` with `_presses`, `_moveAll`, `_turnAll`,
  `_keepHeldInField`, `_highlight` and `_tapAll`, moved verbatim except that the three static members they read
  (`speed`, `dotRadius`, `stickTurnFactor`) are now written `PuzzleGame.speed` etc., as the analyzer requires
  once they sit in an extension. An extension is the right tool here: the six helpers are all `this`-methods
  on `PuzzleGame`, and the private ones must stay in the library.

`puzzle_carry.dart` 126 → 110 (`_keepHeldInField` left it), `puzzle_drop.dart` untouched (179). `PuzzleGame`
keeps its state, `update()`, the drop/turn entry points and `_noteTime`. No test changed for this step; the
whole suite (283 tests) passed without edits, and the four mirror screenshots kept their sha1 (below).

### 2. puzzle_rules.dart split

`puzzle_rules.dart` 391 → 115 lines, now four parts:

- `puzzle_rule_pieces.dart` (62): `_ids`, `_kinds`, `_held`.
- `puzzle_rule_look.dart` (39): `_colours`.
- `puzzle_rule_levels.dart` (92): easy/medium constants, `_level`, `_levelIssue`, `_repeatedShapes`.
- `puzzle_rule_fit.dart` (149): `pictureSpanShare`, `splitMinScale`, `_picture`, `_fit`, `_span` and the new
  tray rule `_trayStarts` (seeds 0–199).

All are parts, not extensions, because they are mostly plain functions and constants over a `Puzzle`, not
methods on a receiver; `checkPuzzle` in the main file calls them as `_ids(...)`, `_fit(...)`, and so on.
`PuzzleRule`, `PuzzleIssue`, `checkPuzzle`, `checkLibrary` and `_prefix` stay in `puzzle_rules.dart`.

### 3. Tray rule moved into `check`

`PuzzleGame(puzzle, random: Random(seed))` lays the tray out for seeds 0–199 and, for each piece, compares its
tray box (`shape.bounds(angle).shift(pos)`) with every other piece's and with the tray rect:

- overlap (first per pair):
  `x/a: at start 12 its tray box overlaps "d"'s, and two boxes may not overlap at any start from 0 to 199. Make one of them smaller, or fewer pieces big.`
- leaving the tray (first per piece):
  `x/a: at start 3 its tray box leaves the tray, and it must fit at every start from 0 to 199. Make it smaller, or fewer pieces big.`

`trayStartSeeds = 200` is a named constant next to `splitMinScale`. The containment half is new to `check`
(the old `puzzle_size_test.dart` asserted it for real puzzles); it is kept so no check got weaker. Test first:
with the `_trayStarts` call commented out, the new test in `puzzle_rules_test.dart` failed
(`Expected: an object with length of <7>, Actual: []`); restored, it passes. The test puzzle breaks only the
tray rule (7 fit issues, all overlaps), so the message is pinned word for word.

The two remaining test-only rules — at least 2 pieces start turned (Easy exactly 2) and every piece at least
`minPieceMm` on the narrowest phone — are **not** in `check` yet; see "Stopped".

### 4. `Level.hard` refused everywhere, in the same words

`puzzleLevels = ['easy', 'medium']` and
`String notALevel(String level) => '"$level" is not a level: use ${puzzleLevels.join(' or ')}';` live in
`puzzle.dart`. The parser throws it in `fromJson`, `_level` in the rule book reports it as an issue, and
`puzzle.schema.json` has the same sentence in `errorMessage` with `enum: ["easy", "medium"]`; the test-side
schema validator substitutes `{value}`. `tools/puzzle_new.dart` already said exactly this (its
`newPuzzleLevels` is the same pair), so it needed no change; `puzzle_new_test.dart` pins the equality.
Test first: with the parser check weakened, the new format test failed
(`Actual: returned <Instance of 'Puzzle'>`); restored, it passes.

### 5. Bare casts in the parser now name the puzzle and field

`fromJson`/`parse` used `as` casts; they now throw `FormatException`s:

- `Puzzle "x": "name" must be text, got 7`
- `Puzzle "x": a piece's "id" must be text, got false`
- `Puzzle "x", piece "a": "kind" must be text, got true`
- `Puzzle "x", piece "a": "angle" must be a number, got "6"`
- `Puzzle "x", piece "a": "at" must be [x, y], got [1, "2"]`
- `A puzzle file is a JSON object: {"id": ..., "pieces": [...]}` (whole-file JSON is not an object)

`puzzle_format_test.dart` (31 → 77) covers each; `parse` no longer throws a bare `TypeError` on any of them.
`puzzle.dart` was 433 lines after these changes, over the 400 review limit, so `PieceShape`, `_toSegment` and
`_symmetry` moved verbatim into `piece_shape.dart` (187), leaving `puzzle.dart` at 249.

### Docs

`docs/puzzles.md` 136 → 138: the level row now says Hard is refused by schema, parser and `check`, in the same
words as `tools/puzzle.sh new` (the line-42 claim that Hard was usable); the rules paragraph says the tray is
laid out at every start from 0 to 199 and no box may leave it or overlap another (R4 finding 6's stale
"not in check yet" text is now correct for what `check` does); the turning section says every library puzzle
starts with at least 2 pieces turned. The "rules not in `check` yet" block now lists two, not three.

## Stopped: two of the three rules cannot land in this job

The turned minimum and the phone-size rule both fail on `puzzles/_template.json`, and that file is outside the
allow list. Measured today on the current code:

- `template`: 1 piece starts turned (only `top` is `"rotated": true`; `dot left`/`dot right` are circles, so
  their angle stays 0). Easy wants exactly 2.
- `template` on the narrowest phone ("small 16:9", 640 × 356 px safe area = 101.6 × 56.515 mm; board drawn at
  55.12 mm, so 1 unit = 0.689 mm): smallest piece `dot right` (circle r = 5, 10 units) is 6.89 mm, under
  `minPieceMm` 8.5.
- Every other puzzle in the library passes both, and all 13 files (12 puzzles and the template) have no tray
  overlap or escape at seeds 0–199.

`puzzle_new_test.dart` pins the template's pieces and asserts that a freshly created puzzle passes
`checkPuzzle` and `checkLibrary`, so adding either rule without a template fix turns that test red. Fix needed,
in `packages/puzzle_game/puzzles/_template.json` (not mine to make): add `"rotated": true` to `base` (a
non-square rect, so a turned start is real) and grow both dots to radius 7 and 8 (7 and 8, not equal, so Easy's
"no two pieces of the same shape and size" still holds). At 0.689 mm per board unit on the narrowest phone their
diameters are 9.65 mm and 11.02 mm, both above 8.5.

I did not write the two rules at all rather than add them behind an exception: half a rule with a carve-out for
the template would be worse than none.

The narrowest-phone constant (`small 16:9` board = 80 × 72 units at 55.12 mm wide, i.e. `minPieceMm` measured
against 55.12 mm) and the `controller_app/test/puzzle_size_test.dart` change that pins the real layout is never
smaller are part of the same blocked item, so neither exists yet.

## Line counts

| file | before | after |
| --- | --- | --- |
| lib/src/game.dart | 399 | 279 |
| lib/src/puzzle_player.dart | — | 35 |
| lib/src/puzzle_tick.dart | — | 111 |
| lib/src/puzzle_carry.dart | 126 | 110 |
| lib/src/puzzle_rules.dart | 391 | 115 |
| lib/src/puzzle_rule_fit.dart | — | 149 |
| lib/src/puzzle_rule_levels.dart | — | 92 |
| lib/src/puzzle_rule_look.dart | — | 39 |
| lib/src/puzzle_rule_pieces.dart | — | 62 |
| lib/src/puzzle.dart | 383 | 249 |
| lib/src/piece_shape.dart | — | 187 |
| puzzles/puzzle.schema.json | 156 | 157 |
| test/support/schema.dart | 114 | 120 |
| test/puzzle_format_test.dart | 31 | 77 |
| test/puzzle_schema_test.dart | 55 | 61 |
| test/puzzle_rules_test.dart | 129 | 163 |
| test/rules_test.dart | 473 | 457 |
| test/puzzle_new_test.dart | 89 | 92 |
| docs/puzzles.md | 136 | 138 |

`rules_test.dart` shrank because its 200-seed tray loop became a thin loop over `checkPuzzle`; the turned loop
stays until the blocked rule lands. Every moved function is textually identical except the three
`PuzzleGame.`-qualified statics in `puzzle_tick.dart`.

## Tests

| suite | before | after |
| --- | --- | --- |
| puzzle (all tests in `packages/puzzle_game/test`) | 283 | 289 |
| phone (`controller_app`) | 438 | 438 |
| tv | passing | passing |

New tests: `"hard"` refused by the parser, by the schema and by the rule book (one test each), one parser test
covering the six bad-field messages, and the tray rule (7 pinned messages); `puzzle_new_test.dart`'s hard case
now compares against `notALevel('hard')` instead of restating it. In all, 283 → 289. The game split added no
test and changed none, which is the proof it is a pure move.

## Mirror pictures

`flutter test test/mirror_png_test.dart` in `packages/puzzle_game` (which rewrites
`docs/design/m12-mirror-*.png`; the bytes are unchanged, so nothing is modified) gave the same sha1 for its four
pictures (iphone, iphone-stick, 169, stick) before and after every run:

- iphone `c365336952763a074192da37abca235b2c80eb12`
- iphone-stick `b198345901071f121d9897518e50e7130bc7b101`
- 169 `fb6017c28fe558f9ef3f69e69a369e8ca7651cc0`
- stick `77e88294f1cab412cc9b1eece9256e43b68575dc`

## Self-check (docs/review-rules.md part A, 1–5)

1. Every host setup considered: none exists in this job. The game split changes no host widget; all four mirror
   screenshots and the 283 tests of the puzzle suite, unchanged for this step, show the game behaves the same.
2. Kept state starts and ends where it did: `PuzzleGame`'s fields and `PuzzlePlayer`'s fields moved with the
   same values; `update()`, `drop`, `turn` and `_noteTime` are untouched, and the untouched game tests pass.
3. New state combinations: none added to the game. The only new runtime work is `check`'s 200 temporary
   `PuzzleGame` instances, which are created, read and dropped inside the rule; no pause/away/wait/drop/leave
   path changed.
4. Stayed inside the allow list: the 21 files below are all allow-listed (or the report itself); nothing in
   `.github/`, `codemagic.yaml`, `firebase/`, `kenney-audio/`, `docs/PRD*`, `docs/project-notes.md` or
   `tools/release.sh` was touched.
5. Stopped instead of overstepping: the two rules that need `puzzles/_template.json` were not written, the
   narrowest-phone constant and `puzzle_size_test.dart` were left alone, and no template exception was invented.

## Files

- `packages/puzzle_game/lib/src/game.dart`: parts declared; `PuzzlePlayer` and the tick helpers removed.
- `packages/puzzle_game/lib/src/puzzle_player.dart` (new): `PuzzlePlayer`.
- `packages/puzzle_game/lib/src/puzzle_tick.dart` (new): `_presses`, `_moveAll`, `_turnAll`,
  `_keepHeldInField`, `_highlight`, `_tapAll`.
- `packages/puzzle_game/lib/src/puzzle_carry.dart`: `_keepHeldInField` removed here.
- `packages/puzzle_game/lib/src/puzzle_rules.dart`: parts declared; only the enum, issues, `checkPuzzle`,
  `checkLibrary`, `_prefix` remain.
- `packages/puzzle_game/lib/src/puzzle_rule_pieces.dart` (new): `_ids`, `_kinds`, `_held`.
- `packages/puzzle_game/lib/src/puzzle_rule_look.dart` (new): `_colours`.
- `packages/puzzle_game/lib/src/puzzle_rule_levels.dart` (new): level rules, now refusing `hard` via
  `notALevel`.
- `packages/puzzle_game/lib/src/puzzle_rule_fit.dart` (new): fit/span rules plus `_trayStarts` (`trayStartSeeds`).
- `packages/puzzle_game/lib/src/puzzle.dart`: `puzzleLevels`, `notALevel`, typed `fromJson`/`parse` refusals,
  `part 'piece_shape.dart';`.
- `packages/puzzle_game/lib/src/piece_shape.dart` (new): `PieceShape`, `_toSegment`, `_symmetry`.
- `packages/puzzle_game/puzzles/puzzle.schema.json`: level `enum` easy/medium with the parser's sentence.
- `packages/puzzle_game/test/support/schema.dart`: honours `errorMessage` with `{value}` for `enum`.
- `packages/puzzle_game/test/puzzle_format_test.dart`: hard refusal and the six cast messages.
- `packages/puzzle_game/test/puzzle_schema_test.dart`: hard refusal equals `notALevel('hard')`.
- `packages/puzzle_game/test/puzzle_rules_test.dart`: hard rule + tray overlap rule (7 messages pinned).
- `packages/puzzle_game/test/rules_test.dart`: 200-seed loop becomes a thin `checkPuzzle` loop.
- `packages/puzzle_game/test/puzzle_new_test.dart`: hard refusal message pinned to `notALevel`.
- `packages/puzzle_game/test/tmp_board_mm_test.dart`: scratch probe, now empty — delete it.
- `docs/puzzles.md`: Hard refused, tray checked at every start, turned minimum, two remaining rules.
- `docs/briefs/m14/g1-puzzle-groundwork-report.md`: this report.

## Commit message

```
Split the Shape Race rules, and check the tray at every start

game.dart (399 → 279) gives up PuzzlePlayer and its tick helpers;
puzzle_rules.dart (391 → 115) splits into four parts. check lays the
tray out at starts 0-199 and refuses an overlap or a box that leaves
it. The parser, the schema and the rule book refuse "hard" in the
same words as tools/puzzle.sh new, and the parser's casts name the
puzzle, piece and field. The turned and phone-size rules wait for
puzzles/_template.json, which has one turned piece and a 6.89 mm dot.
```

## Status row

| M14 g1: Shape Race groundwork | stopped: game and rules split, tray rule in `check`, `hard` refused, cast messages done; open: the turned minimum and the phone-size rule, blocked by `puzzles/_template.json` (outside allow) |

## Delete

- packages/puzzle_game/test/tmp_board_mm_test.dart

## Claude's review (Nov 9, 2026)

Accepted. Checked: `game.dart` 399 → 279 and `puzzle_rules.dart` 391 → 115 by moves (the game split changed no test);
the mirror pictures' hashes unchanged; the tray rule at seeds 0–199 is in `check` and `rules_test.dart`'s loop is
thin over it; "hard" refused in one wording by the schema, the parser and `check`; the parser's casts name the
field. `tools/check.sh format analyze puzzle phone tv` passed (289 puzzle tests, 438 phone).
- **The stop was right**: two rules with a carve-out for the template would be worse than none. Claude lands them
  in a follow-up commit (g1b): the template gets a second turned piece and dots big enough for the narrowest phone,
  then the turned rule and the phone-size rule go into `check`, with the narrowest board as a constant and the
  phone's test pinning it.
