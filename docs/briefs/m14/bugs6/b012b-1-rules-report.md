# b012b-1-rules: a real Hard level and a per-level start angle (phase 1 of 3)

## Summary

Phase 1 is **partly done**: the Hard rules are in the rule book; the per-level
start angle and the file-level `"hard"` are blocked by files outside `allow:`
(the Blocked section names each one).

- Rule book: Hard now has named limits — 10 to 12 pieces, 3 or 4 big, every
  non-circle piece turned (at least 6), at most 2 shape-and-size pairs. Each
  level has its own function, so Medium's limits are untouched (phase 2). The
  general two-turned-pieces rule no longer skips Hard.
- Start angles: the two bare 30s are one documented `minStartDeg = 30.0`, value
  unchanged, so no layout number moves.
- Docs: Hard's column in the rules-by-level table, the paragraph on what makes
  Hard hard (pieces and turning, never the clock), the 8.5 mm floor and the tray
  rules still deciding the real count, and the `level` field: no file may say
  `"hard"` yet.
- Tests: per-level counts (6 Easy, 6 Medium, 0 Hard) instead of 12 in total; a
  new `puzzle_hard_rules_test.dart` (11 pieces and 4 big accepted; 9 and 13
  pieces, 2 and 5 big, a non-turned piece, five turnable pieces and 3 pairs
  refused; 11 with 2 pairs accepted), each failing on the old code.
- `tools/check.sh format analyze puzzle host`: PASS (419 puzzle, 429 host).

Not done: `"hard"` is still refused by the parser, the schema and `level.sh new`;
the start-angle table (Medium's 60° moves four layout tests); the picker test (the
host already hides empty levels, so nothing fails on the old code). On a device
nothing visible changes yet: that comes with phases 2 and 3.

Questions: 1. May the follow-up hold `tools/level_new.dart` and the three refusal
tests? 2. Should `_phoneSize` stop skipping Hard, so the 8.5 mm floor applies?

## Self-check (review-rules part A)

1. **Every host setup.** Not affected: the diff is the puzzle game's rule book
   (pure Dart, no widget, no platform), one constant, and docs. No host, phone,
   TV or protocol path reads it. `tools/check.sh host` (429 tests) is green; the
   job's checks name no phone or TV suite.
2. **When kept state starts and ends.** Not affected: nothing held, timed,
   counted or cached is added. Start angles keep exactly today's rule, so no
   kept angle or layout changes — `puzzle` (419 tests), which covers the tray
   seeds 0–199 and the split-screen layouts.
3. **How a new state combines with the others.** Not affected: no new state,
   pause, wait or block. The rule book is a pure function of a puzzle —
   `test/puzzle_hard_rules_test.dart`.
4. **Stay in the job's folder.** Done: only files under `allow:` changed (Files
   changed, below); `git status` shows nothing else of mine — the five
   `docs/design` PNGs and the `tv_test_app/windows` generated files were already
   uncommitted in the starting checkout, and the suite redraws the PNGs to the
   same bytes.
5. **Stop rather than overstep.** The four items under Blocked are the ones this
   allow list cannot carry; each names the file outside `allow:` that it needs.
   The rest of the brief was done rather than guessed at.

## Decisions

- **Hard rules live in the rule book only, not in the parser or the schema.**
  Changing `puzzleLevels` and the schema's `enum` breaks `puzzle_format_test`,
  `puzzle_schema_test` and `puzzle_new_test` (all outside `allow:`), and a red
  `check` fails the job, so a Hard *file* waits for a job that may edit them.
- **No per-level start-angle table.** Medium's 60° changes the split-screen
  world size the split-screen layouts pick, which changes the pinned numbers in
  `camera_test.dart`, `mirror_place_test.dart` and `tablet_board_test.dart` (and
  `tray_packing_test.dart`) — all outside `allow:`. Shipping it red is worse
  than shipping it in the next job, so `minStartDeg` (30) is named and the table
  waits.
- **The general turned-piece rule applies to Hard too.** With every non-circle
  piece turned and at least 6 of them, Hard always clears the general 2; leaving
  the skip in would have kept a special case in the rule book.
- **`_counts` takes one record.** The two counts and the level's name would be
  seven parameters, over the "at most 5" guideline; `_PieceCounts` holds the
  level's name and its two ranges, and `_medium`/`_hard` pass a constant.
- **No host change.** `games_screen.dart` already skips a level with no puzzles
  (`if (value.ofLevel(level) case final puzzles when puzzles.isNotEmpty)`), so
  there is nothing to fix there inside `allow:`; the test written for it is
  withdrawn (see Delete) because it passes on the old code.

## Blocked: what each remaining piece of phase 1 needs

1. **A file may say `"hard"`** (parser, schema, `level.sh new`).
   - `packages/puzzle_game/lib/src/puzzle.dart`: `puzzleLevels` → `['easy', 'medium', 'hard']`.
   - `packages/puzzle_game/puzzles/puzzle.schema.json`: `level.enum` + description.
   - Outside `allow:`: `test/puzzle_format_test.dart` ("hard is not a level"),
     `test/puzzle_schema_test.dart` ("a Hard puzzle is refused"), and
     `tools/level_new.dart` (`newPuzzleLevels` plus its message), which keeps
     `test/puzzle_new_test.dart` green.
   - One job that holds all of these closes it; phase 2's `test/` folder would
     cover the two tests but not `level_new.dart`.
2. **The start-angle table** (Easy 30, Medium 60, Hard 90, both functions).
   - Outside `allow:`: `test/camera_test.dart`, `test/mirror_place_test.dart`,
     `test/tablet_board_test.dart`, `test/tray_packing_test.dart`, and
     `test/puzzle_rules_test.dart`'s "no two pieces' tray boxes overlap at any
     start" (this one is in `allow:`; its 7 issues became 2 with Medium at 60).
   - A square or a triangle cannot start 90° off (its symmetry caps the error at
     45° and 60°), so the table needs `least = min(levelMin, symmetry / 2)` and
     the sampling has to pick the error directly: with 90° as the floor for a
     rectangle, the old 50-try loop never lands on it.
3. **The picker test** — the behaviour exists already; nothing to test-first.
   The real, small bug nearby is `autofocus: i == 0` in `games_screen.dart`
   (the enum index, not the first offered level), so a library with no Easy
   puzzle focuses no card at all; it is outside `allow:`.

## Checks run

- `tools/check.sh format analyze puzzle host` — PASS, run at 17:00 (log
  `thumbparty-check-20261114-170058`): 419 puzzle tests, 429 host tests. The two
  withdrawn test files were still present; the Delete list removes them before
  the harness's check, and they pass today, so it stays green.
- `tools/check.sh puzzle` alone, earlier, with the start-angle table in place:
  5 red tests, 4 of them in files outside `allow:` (`camera_test` boat 4.6574 →
  4.6304 pxPerUnit, `mirror_place_test` 92.6 → 92.943, `tablet_board_test`
  9.671142 → 9.699315, `tray_packing_test` 10.273 → 10.913) and one in
  `puzzle_rules_test.dart` (its tray overlap count 7 → 2). That is the evidence
  for Blocked item 2; the same suite is green now, 419 tests.

## Computed test values

`puzzle_hard_rules_test.dart` (each fails on the old code, which reported
`"hard" is not a level: use easy or medium` for every one):

| Case | Expected |
| --- | --- |
| 11 pieces, 4 big, all turned | no `level` issue |
| 9 pieces / 13 pieces | `a Hard puzzle has 10 to 12 pieces, this one has 9` / `… has 13` |
| 2 big / 5 big | `a Hard puzzle has 3 or 4 big pieces, this one has 2` / `… has 5` |
| piece `p7` not turned | `h/p7: it does not start turned, and every piece of a Hard puzzle that is not a circle does. Set "rotated" on it, or make it a circle.` |
| 10 pieces, 5 circles, 5 turned | `a Hard puzzle starts at least 6 pieces turned, this one starts 5` |
| 6 pieces of one shape and size | 3 issues, `a Hard puzzle has at most 2 such pairs` |
| 11 pieces, 3 of one shape, 3 big, all turned | no `level` issue |

`library_test.dart`: 6 Easy, 6 Medium, 0 Hard, ids unchanged.

`start_angles.dart` (unchanged behaviour), measured with the withdrawn test:
every turned piece of a bar, a square and a triangle started at least
`minStartDeg` (30°) off, at every level, over seeds 0–99, in `startAngles` and in
both `compactStartAngles` trays.

## Files changed

- `packages/puzzle_game/lib/src/puzzle_rule_levels.dart` — Hard's constants,
  `_easy`/`_medium`/`_hard`/`_counts`/`_hardTurned`, no skip for Hard in
  `_turned`.
- `packages/puzzle_game/lib/src/start_angles.dart` — `minStartDeg`, used by both
  functions in place of the bare 30.
- `packages/puzzle_game/lib/src/puzzle.dart` — comments only: what a level file
  may say now that Hard has rules, and what `rotated` means.
- `packages/puzzle_game/test/puzzle_hard_rules_test.dart` — new, 3 tests.
- `packages/puzzle_game/test/puzzle_rules_test.dart` — the Hard-refusal test
  removed (Hard has rules now; its cases moved to the new file).
- `packages/puzzle_game/test/library_test.dart` — per-level counts.
- `docs/levels.md` — Hard's column and paragraph, the turning paragraph, the
  `level` field's line.
- `docs/briefs/m14/bugs6/b012b-1-rules-report.md` — this report.

## Hand-over for phases 2 and 3

- Phase 2's `allow:` already holds all of `packages/puzzle_game/test`, so it can
  close Blocked item 1 for the parser and the schema; it still cannot touch
  `tools/level_new.dart`.
- Phase 3 needs `"hard"` files to load, so item 1 must land before it; otherwise
  its six Hard puzzles cannot be checked by `tools/level.sh check`.
- Item 2 (the start-angle table) is its own small job: `start_angles.dart`, the
  four layout tests and `puzzle_rules_test.dart`'s tray case.
- `puzzle_rule_fit.dart`'s `_phoneSize` still returns early for Hard, so the
  8.5 mm floor does not run on a Hard puzzle yet; the brief wants it to, so that
  line needs a job that may edit `puzzle_rule_fit.dart`.

## Commit message

Give Hard its piece rules in the rule book (B-012b, phase 1)

Hard is a level with limits of its own: 10 to 12 pieces, 3 or 4 big, every
piece that is not a circle turned (at least 6), at most two shape-and-size
pairs. The counts live in puzzle_rule_levels.dart as named constants, and
_level sends each level to its own function, so Medium is untouched.
The general two-turned-pieces rule no longer skips Hard, and the two bare 30s
in start_angles.dart are one documented minStartDeg, ready for the per-level
table. docs/levels.md gains Hard's column and the 8.5 mm and tray note, and
library_test asserts one count per level instead of 12 in total.
The parser, the schema and the per-level start angles are blocked by tests
outside this job's allow list; the report names each file.

## Status row

B-012b phase 1: Hard has named piece rules in the rule book with tests and docs (10-12 pieces, 3-4 big, every non-circle turned, ≤2 pairs); open: a file may not say `"hard"` yet (parser, schema, `level_new.dart`), the per-level start-angle table (Medium's 60° moves four layout tests), the host picker test, and `_phoneSize` skipping Hard.

## Delete

- packages/puzzle_game/test/start_angles_test.dart
- packages/party_host/test/games_screen_levels_test.dart
