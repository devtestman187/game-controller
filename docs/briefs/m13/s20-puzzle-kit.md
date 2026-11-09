job: M13 11: a puzzle kit, so a developer can add a puzzle safely (owner, Nov 9, 2026: "How are puzzles captured in code? Can we make it easy for developers to add new puzzles using a set format or template? Remember to use best game coding practices. Think of how other puzzle games or games with maps may handle this." Then, of Claude's proposal: "Yes for the puzzle kit.")
pub: no
stop: after it.
read: packages/puzzle_game/puzzles/*.json, index.json · packages/puzzle_game/lib/src/puzzle.dart (the parser, `PieceShape`, its `FormatException`s), library.dart, tray.dart, split_layout.dart, game.dart (sizes) · docs/briefs/m13/s17-puzzles.md and its report (the rules s17 wrote as tests: held inside, board contrast, colour distinctness, layout) · packages/toy_look/lib/src/toy_colors.dart · tools/check.sh, tools/review.sh, tools/flash_usage.dart (how a repo tool is written) · docs/review-rules.md · docs/coding-guidelines.md

Today a puzzle is a JSON file listed in `index.json`, parsed at start-up; only the syntax is checked. Every bug we found on devices this week was a puzzle that parsed but played or looked wrong (a piece held by a point on its edge; a piece the colour of the board). Level-based games keep levels as data with a small toolchain round the format: a schema for the editor, a linter in CI, a template, a preview render, palette tokens and a format version. This job builds that.

Claude's design:
1. **The format, versioned and described.** Each puzzle file starts with `"$schema": "puzzle.schema.json"` and `"format": 1`. `puzzles/puzzle.schema.json` (JSON Schema 2020-12) describes every field — shapes (`rect`, `circle`, `polygon`, `regular`), `at`, `color`, `big`, `rotated`, `kind`, `level`, `name` — with a description each, so VS Code autocompletes and flags mistakes as you type. The parser accepts `$schema`, accepts `format` 1 (missing means 1), and refuses a higher format with a clear message. Update every puzzle file.
2. **Colour tokens.** `color` may be a palette name (`"red"`, `"sky"`, `"silver"`, …) or `"#RRGGBB"`. The names are a `PieceColors` table in puzzle_game, picked from the toy palette so each one passes the board-contrast rule in Sunny and Night (a test proves it). Convert the existing puzzles to tokens where a token matches; keep hex where none does.
3. **One rule book.** `lib/src/puzzle_rules.dart`: a pure function from a puzzle (and the library, for index rules) to a list of issues — `{puzzle, piece?, rule, message}` with a message a developer can act on ("rocket/body: #D5DBDB is 0.09 from the Sunny board; it needs 0.15. Try "silver" or "steel"."). It holds every rule: ids unique; held by a point strictly inside; board contrast in both looks; colours told apart in a puzzle; fits the board and the tray, on one board and split; the level's limits (Easy 4–5 pieces, few turned, no repeated shape; Medium 6–8, one or two big, at most one repeated pair); `kind` pieces share a shape; every file listed in `index.json` and every listed id has a file. s17's tests become thin tests over this rule book (no rule written twice), and a test runs it over the whole library and fails on any issue.
4. **The tool.** `tools/puzzle.sh` with three commands:
   - `new <id> --level easy|medium [--name "Name"]`: copies `puzzles/_template.json` (a small valid puzzle with comments in its `description` fields' place, i.e. a `"notes"` field the parser ignores) to `puzzles/<id>.json` with the id, name and level filled in, and adds it to `index.json` at the end of its level. Plain Dart (no Flutter), so it's instant.
   - `check [id]`: runs the rule book over every puzzle (or one) and prints the issues, one line each, exit 1 if any. The rule book needs Flutter's `Offset`, so this runs through `flutter test` on a dedicated test file with readable output; that's fine.
   - `render <id>`: writes `docs/design/puzzles/<id>.png`: the empty board, the finished picture and the tray, Sunny and Night, through `flutter test` like the other pictures.
   Files starting with `_` (the template) are never puzzles.
5. **The guide.** `docs/puzzles.md`, one page: the board's coordinate system and size (with a small diagram), the shapes, where `at` points, how turning and symmetry work, the level rules, the colour tokens with swatches, and the workflow (`new` → edit with the schema's help → `check` → `render` → look → commit). Link it from the README's development section.
6. Keep it data-driven: no puzzle is named in code, and adding a puzzle is a file and an index line, as now.

tests (each failing first):
- The schema validates every puzzle file and rejects a broken one (a missing `at`, a bad colour, an unknown shape). A small Dart validator for the schema subset you use is fine; install nothing.
- The parser: `$schema` ignored, `format` 1 or missing accepted, `format` 2 refused with a message.
- Tokens: every token passes board contrast in both looks; a token and its hex parse to the same colour; an unknown token is a clear error.
- The rule book: one test per rule with a puzzle that breaks just that rule and the message it gives; and the whole library has no issues.
- `new`: a new id appears with the template's content, in `index.json` after the last of its level, and passes `check` unchanged.
- `render` writes a deterministic picture.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit).

in the report: test counts before and after; the files changed; the token table (name, hex, contrast in Sunny and Night); the rule list with an example message for each; a transcript of `new`, `check` and `render` on a scratch puzzle (then delete it).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/party_host, the painters, camera.dart or match_painter.dart (other jobs are working there) · the puzzle tests rewrite docs/design/m12-mirror-*.png: they should come out unchanged; if one changes, say why.
allow: docs/briefs/m13/s20-puzzle-kit-report.md · docs/puzzles.md · docs/design/puzzles · README.md · tools/puzzle.sh · tools/puzzle_new.dart · packages/puzzle_game/puzzles · packages/puzzle_game/lib/src/puzzle.dart · packages/puzzle_game/lib/src/library.dart · packages/puzzle_game/lib/src/puzzle_rules.dart · packages/puzzle_game/lib/src/piece_colors.dart · packages/puzzle_game/lib/puzzle_game.dart · packages/puzzle_game/test
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s20-puzzle-kit-report.md
