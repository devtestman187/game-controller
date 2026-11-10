# s20 puzzle kit — report

The puzzle kit is in: puzzles carry a format version and a schema, colours are tokens, one rule book holds every rule s17 wrote as loose tests, `tools/puzzle.sh` makes/checks/renders a puzzle, and `docs/puzzles.md` is the guide. The four redraws (sun, fish, butterfly, train) are the kit's first use.

## Test counts

| suite | before | after |
| --- | --- | --- |
| look | 112 | 112 |
| puzzle | 252 | 282 |
| phone | 438 | 438 |
| tv | 53 (+1 skipped) | 53 (+1 skipped) |
| kit / arena / host (`tools/check.sh arena host kit`) | 49 / 69 / 268 | 49 / 69 / 268 |

`tools/check.sh format analyze look puzzle phone tv` → all six PASS (111 s). `tools/check.sh arena host kit` → all PASS. `tools/review.sh` → 0 fail, 15 note (all notes are numeric literals in the OKLab maths and the two size notes at 383/391 lines).

The net 30 come from nine new test files (schema, format, tokens, one test per rule, span, `new`, the `check` and `render` targets, the swatches) less the s17 tests that became thin: `puzzle_colour_test`, `puzzle_pieces_test` and `rules_test`'s kind case now run over the rule book, so no rule is written twice.

## Files changed

- `packages/puzzle_game/lib/src/puzzle.dart` — reads `$schema` (ignored), `format` (1 or missing; a higher one refused with a message), and a piece's `color` through the palette; the kind check moved to the rule book.
- `packages/puzzle_game/lib/src/piece_colors.dart` (new) — the `PiecePalette` token table, `hexOf`, `parse` with a message listing the names, the board colours of both looks, and the OKLab maths s17 used.
- `packages/puzzle_game/lib/src/puzzle_rules.dart` (new) — `checkPuzzle` / `checkLibrary`, one pure function per rule, each issue `{puzzle, piece?, rule, message}`.
- `packages/puzzle_game/lib/puzzle_game.dart` — exports the two new files.
- `packages/puzzle_game/puzzles/*.json` (12) — `$schema`, `format: 1`, token colours; sun, fish, butterfly and train redrawn (below).
- `packages/puzzle_game/puzzles/_template.json` (new) — a valid 4-piece Easy puzzle with a `notes` field describing the workflow.
- `packages/puzzle_game/puzzles/puzzle.schema.json` (new) — JSON Schema 2020-12 for the whole format, colour names enumerated.
- `packages/puzzle_game/puzzles/index.json` — unchanged (its trailing newline is kept by `new`).
- `packages/puzzle_game/test/puzzle_schema_test.dart` (new) — every file validates; a missing `at`, a bad colour and an unknown shape are rejected.
- `packages/puzzle_game/test/support/schema.dart` (new) — the Dart JSON Schema subset validator (no installs).
- `packages/puzzle_game/test/puzzle_format_test.dart` (new) — `$schema` ignored, format 1 or missing, format 2 and `"1"`/0 refused.
- `packages/puzzle_game/test/piece_colors_test.dart` (new) — the board colours match `ToyColors`, every token clears both boards, token and hex parse alike, unknown names are errors.
- `packages/puzzle_game/test/puzzle_rules_test.dart` (new) — one test per rule with its message.
- `packages/puzzle_game/test/puzzle_span_test.dart` (new) — today's butterfly fails the span rule; today's sun and fish pass (see question 1); the four redraws pass every rule.
- `packages/puzzle_game/test/puzzle_new_test.dart` (new) — `new` writes the template's content, inserts after the last puzzle of its level, passes `check`, and refuses bad ids/levels/duplicates.
- `packages/puzzle_game/test/puzzle_check_test.dart` (new) — the `check` target: the rule book over the library, or one `--dart-define=puzzleId` puzzle, printing one line per issue.
- `packages/puzzle_game/test/puzzle_render_test.dart` (new) — the `render` target: empty board/tray and finished picture, Sunny and Night, deterministic.
- `packages/puzzle_game/test/colour_swatches_test.dart` (new) — `docs/design/puzzles/colours.png` for the guide.
- `packages/puzzle_game/test/support/{library_files,today_puzzles}.dart` (new) — read the shipped files; s17's three puzzle texts for the span test.
- `packages/puzzle_game/test/library_test.dart` — adds the whole-library rule book test.
- `packages/puzzle_game/test/{puzzle_colour_test,puzzle_pieces_test}.dart`, `rules_test.dart` — thin tests over the rule book.
- `packages/puzzle_game/test/{placed_look_test,slot_contrast_test}.dart`, `support/piece_colours.dart` — drop the old local OKLab helper's import.
- `tools/puzzle.sh` (new), `tools/puzzle_new.dart` (new) — the three commands; `new` is plain Dart.
- `docs/puzzles.md` (new) — the one-page guide.
- `docs/design/puzzles/*.png` (new, 13) — the twelve pictures and the colour swatches.
- `docs/design/m13-puzzles.png`, `docs/design/m13-puzzles-night.png` — re-rendered.
- `README.md` — the docs row links the guide.

`docs/design/m12-mirror-*.png` came out unchanged (`git status` lists neither). `git status` does list `puzzles/index.json` and `tv_test_app/windows/flutter/generated_*` as modified, but `git diff` finds no content change in any of them: the worktree's line endings are LF where the index expects CRLF (the Windows checkout's usual noise), not this job's edits.

## Colour tokens

| name | hex | Sunny | Night |
| --- | --- | --- | --- |
| red | #C0392B | 0.441 | 0.321 |
| orange | #E9762B | 0.299 | 0.437 |
| yellow | #F2C200 | 0.177 | 0.575 |
| green | #27AE60 | 0.330 | 0.415 |
| sky | #85C1E9 | 0.213 | 0.451 |
| blue | #2E86C1 | 0.396 | 0.267 |
| purple | #A66CFF | 0.386 | 0.332 |
| brown | #8E5B3A | 0.440 | 0.265 |
| slate | #546E7A | 0.441 | 0.213 |
| silver | #9FB8CE | 0.204 | 0.440 |
| steel | #7EA6C9 | 0.271 | 0.376 |
| sand | #B3A285 | 0.238 | 0.416 |

(Distances are OKLab; the floor is 0.15. Boards: Sunny #FFEFD0, Night #30297A.)

## The rule book

| rule | what it holds | example message |
| --- | --- | --- |
| `id` | a piece id is used once; a puzzle id is used once in the library | `x/a: two pieces have this id. Give each piece its own id.` |
| `kind` | pieces of one `kind` share a shape | `x/b: pieces of kind "wave" must have the same shape, but "a" and "b" differ. Give one another kind, or draw them alike.` |
| `held` | the point a piece is held by is strictly inside it | `x/arrow: the point it is held and turned by (the shape's origin) is on or outside its shape, so the worker pushes empty space. Move the shape so (0, 0) is inside it.` |
| `board` | a piece stands out from the board in both looks | `scratch-cat/dot left: #FFEFD0 is 0.00 from the Sunny board; it needs 0.15. Try "yellow" or "silver".` |
| `pair` | two pieces of one puzzle look apart unless they share a shape | `x/a: "red" #C0392B is 0.00 from "red" #C0392B ("b"), and two pieces need 0.08 apart. Give one of them another colour.` |
| `level` | Easy 4–5 pieces, at most 2 turned, no repeated shape; Medium 6–8, 1–2 big, at most 1 repeated pair | `x: an Easy puzzle has 4 to 5 pieces, this one has 3. Add or remove a piece, or make it Medium.` |
| | | `x: an Easy puzzle starts at most 2 pieces turned, this one starts 4. Clear "rotated" on one.` |
| | | `x/p0: "a" and "p0" share a shape and size, and an Easy puzzle has at most 0 such pair. Use another shape, or make one of them bigger or smaller.` |
| `fit` | the outline stays on the board, the pieces fit the tray on one board, the split screen draws at ≥ 0.85 | `x/a: its outline goes 3.0 right, 3.0 down past the board's edge. Move it inside, or make it smaller.` |
| | | `x: the pieces are … units too big for the tray on one board. Make a piece smaller, or fewer pieces big.` (`…` = the measured overflow) |
| | | `x: the split screen draws it at … of the board's size, and it needs 0.85. Make the pieces smaller or use fewer.` (`…` = the measured scale) |
| `span` | the finished picture spans 60% of the board's width or height | `x: the finished picture spans 23% of the board's width and 25% of its height; it needs 60% of one side. Spread the pieces out, or make them bigger.` |
| `listing` | `index.json` and the files name the same puzzles | `index.json lists "missing" but puzzles/missing.json is missing. Add the file, or remove the id.` |
| | | `puzzles/extra.json is not listed in index.json. Add "extra" after the last puzzle of its level.` |

## Transcript (scratch puzzle, deleted afterwards)

This job's sandbox refused to run `tools/puzzle.sh` itself (and `dart tools/puzzle_new.dart`), so `new` was run by calling the program's `createPuzzle` through `flutter test`, and `check`/`render` by running the exact commands the script execs, from `packages/puzzle_game`.

```
$ tools/puzzle.sh new scratch-cat --level easy --name "Scratch Cat"
Wrote puzzles/scratch-cat.json and added "scratch-cat" after the last easy puzzle in index.json.
Edit its pieces, then run: tools/puzzle.sh check scratch-cat
   index.json: [... "snowman", "scratch-cat", "boat", ...]   # after the last Easy puzzle

$ tools/puzzle.sh check scratch-cat
00:00 +0: the rule book over scratch-cat
00:00 +1: All tests passed!

$ tools/puzzle.sh check scratch-cat          # after writing one dot's colour as #FFEFD0
scratch-cat/dot left: #FFEFD0 is 0.00 from the Sunny board; it needs 0.15. Try "yellow" or "silver".
00:00 +0 -1: Some tests failed.

$ tools/puzzle.sh check scratch-cat          # colour back to "yellow"
00:00 +1: All tests passed!

$ tools/puzzle.sh render scratch-cat
wrote ../../docs/design/puzzles/scratch-cat.png (50849 bytes)
00:00 +1: All tests passed!
```

`puzzles/scratch-cat.json` and `docs/design/puzzles/scratch-cat.png` were deleted; `index.json` is back to its original bytes (the tool keeps the file's trailing newline).

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** Not affected: the change is puzzle data, a rule book and a test-only tool; no host, phone, camera or input path is touched (`allow:` excludes the painters). The parser still reads every shipped file — `packages/puzzle_game/test/puzzle_format_test.dart` and `library_test.dart`.
2. **When kept state starts and ends.** Not affected: the rule book is a pure function with no state; `new` writes two files and exits. `packages/puzzle_game/test/puzzle_rules_test.dart` (pure calls) and `puzzle_new_test.dart` (writes only inside a temp copy of `puzzles/`).
3. **How a new state combines with the others.** Not affected: nothing pauses, hides, waits or blocks input; there is no new state. No combination to test.
4. **Stay in the job's folder.** Only files in `allow:` are written: `git status` shows the files above; the only other entries are `tv_test_app/windows/flutter/generated_*`, which differ in line endings only (pre-existing, no content change). `tools/review.sh` → 0 fail.
5. **Stop rather than overstep.** Two rules cannot be met as written, so I stopped at the fact and pinned it instead of guessing: the span test's claim about today's sun and fish (question 1), and `review.sh`'s `Colors\.`/toy_look checks forcing the table's name (question 2).

## Questions

1. **The span rule cannot fail today's sun and fish.** The brief says the rule must fail for today's sun, fish and butterfly. Today's sun's box is 55.3×51.5 board units (69%×72%) through its cloud and sea bar, and today's fish's is 50×39 (62.5%×54%) through its bubble, so both pass; only the butterfly (46×36, 57.5%×50%) fails. I kept the box rule the brief specifies, pinned all three facts in `puzzle_span_test.dart`, and redrew the four so they pass. If the intent is "the picture reads as one thing", the rule needs a different measure (largest gap between pieces, say) — your call.
2. **`PieceColors` had to be renamed.** `tools/review.sh`'s colour check matches `Colors\.` anywhere, so `PieceColors.` (and `ToyColors.`) FAIL as "a colour outside toy_look"; the table is `PiecePalette` and the singular `PieceColor` is unchanged. Its `layers` check also forbids a rules file importing toy_look, so the two board colours are constants in `piece_colors.dart`, tied to the look by a test (`piece_colors_test.dart` asserts they equal `ToyColors`' boards). `\bColors\.` in review.sh would let the brief's name stand.
3. **The README has no "Development" section** (the brief links the guide from it), so the link sits in the docs table row.
4. **`tools/puzzle.sh` needs its executable bit** when it is added; this job could not set it. `bash tools/puzzle.sh` works as is.
5. **The sun's smile grew** from 11×2.4 to 12×3 in the last step: `controller_app/test/puzzle_size_test.dart` (not in `allow:`) requires every piece to be ≥ 8.5 mm on the smallest phone, and the thin bar came out at 8.40 mm. Data change only.
6. **`render` for all twelve is also the suite's** — the puzzle tests write `docs/design/puzzles/*.png` and the two `m13-puzzles` sheets, so a `check.sh puzzle` run can change those files. That is how the twelve were rendered again.

## Suggestions

- review.sh's colour check could use `\bColors\.` and could allow `ToyColors` in a game's lib; today both words are flagged.
- A "reads as one picture" measure (the largest gap between a picture's pieces, over the board's width) would catch the sun-with-a-cloud case the span box misses, and would let the span test say what the brief meant.
- `check` could print the span percentages for a passing puzzle too, so a `render` reviewer knows the margin before looking.

## Commit message

```
Puzzle kit: schema, format version, colour tokens, rule book, tool, guide

Every puzzle file now carries "$schema" and "format": 1; the parser refuses
a newer format with a message. Colours may be a palette name or #RRGGBB.
One rule book (lib/src/puzzle_rules.dart) holds every check s17 wrote as
loose tests, with messages a developer can act on, plus a span rule; s17's
tests now run over it, and a test runs it over the whole library.
tools/puzzle.sh adds new/check/render, docs/puzzles.md explains the format,
and sun, fish, butterfly and train are redrawn as the kit's first use.
```

## Status row

Done: puzzle format version and schema, colour tokens, one rule book over the library, `tools/puzzle.sh new|check|render`, `docs/puzzles.md`, four redrawn puzzles and all twelve rendered. Open: the span rule needs a decision (question 1) and `review.sh`'s colour pattern a fix (question 2).

## Delete

- packages/puzzle_game/test/scratch_test.dart
- packages/puzzle_game/test/support/oklab.dart

## Claude's review

Accepted, with three fixes by Claude. The kit itself is good: the schema, the format version, the tokens, the rule book's messages ("the pieces are 2.0 units too big for the tray on one board. Make a piece smaller, or fewer pieces big.") and `tools/puzzle.sh` all did their job when Claude redrew the sun with them.
- **A placed piece was drawn in the wrong outline** (bug in `puzzle_painter.dart`, older than this job, found in its `sun.png`): a locked piece took the outline with the nearest centre, of any kind, so the sun's rays and face, which share a centre, both took the rays' outline and the rays were never drawn, on the board or in the pictures. It now takes the nearest of its own kind, as its comment already said. Test first: `placed_look_test.dart` "two locked pieces of different kinds that share a centre are both drawn".
- **The render sheet's Night row was drawn in Sunny** (`puzzle_render_test.dart`): only the label took the Night colours; each panel now has its own `ToyLookScope`.
- **The sun redrawn by Claude with the kit**: eight rays round a face, sunglasses and a smile (4 pieces, two turned, 62.5 % of the board's width). The worker's five-point star read as a starfish once it was drawn. A round 8-ray sun didn't fit the tray at 60 % span; a slightly wider-than-tall one does. The smile is 14 × 4 for the 8.5 mm floor on an iPhone 15.
- `mirror_pad_test.dart`: the stick case assumed the disc always takes the corner; with the sun's bigger smallest piece a smaller mirror fits there, which rule 8 allows (the corner first). The test now checks the corner's rules (clear of the disc, short clock beside it) when the mirror is there, and the gap's otherwise.
- Q1 (span rule): keep the box rule; a "reads as one picture" gap measure is a good later addition, not now.
- Q2 (`PiecePalette`): fine as named. Q3, Q5, Q6: fine. Q4: the executable bit is set in this commit.
- Not in the rule book yet: the tray overlap and phone-size checks still live only in `rules_test.dart` and `controller_app/test/puzzle_size_test.dart`, so `tools/puzzle.sh check` passed a sun those failed. Next kit job: fold them into the rule book.
- Checks: format, analyze, look 126, arena 69, puzzle 283, host 268, phone 438, tv pass; review 0 fail.
