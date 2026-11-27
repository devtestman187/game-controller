# d2a report: Arena map difficulty tier

Status: done. The tier field is added, read, checked and compared. Nothing rates a map yet (d2b does that).

## Files changed

- `packages/test_game/lib/src/arena_map.dart`: 395 → 308 lines. Adds `mapTiers`, `notATier`, the `tier` field (constructor, fromJson, `==`, hashCode). The private static parse helpers move out to the part file, and the `part` line now names `arena_map_parse.dart`.
- `packages/test_game/lib/src/arena_map_parse.dart` (new): the parse helpers `_race`, `_bumper`, `_wall`, `_hazard`, `_text`, `_number`, `_point`, `_rect`, `_list` as top-level private functions, bodies unchanged apart from the dedent.
- `packages/test_game/lib/src/arena_map_pieces.dart`: `ArenaMap._point(`, `ArenaMap._text(` and `ArenaMap._number(` become `_point(`, `_text(`, `_number(` (the helpers are no longer on the class).
- `packages/test_game/maps/map.schema.json`: optional `tier` property (enum easy, medium, hard; errorMessage "{value} is not a tier: use easy, medium or hard"). Not in `required`.
- `packages/test_game/maps/_template.json`: `"tier": "easy"` after `"theme"`.
- `packages/test_game/test/map_tier_test.dart` (new): 8 tests, written first and seen failing (undefined `tier`, `notATier`, `mapTiers`), then passing after the lib change.

Not changed: `map_schema_test.dart`, `map_parse_test.dart`, `puzzle_new_test.dart`. The new rules are covered in the new file, and the existing tests needed no edit.

## Checks

- `tools/mine.sh` after the refactor (step 1): format ok, analyze ok, `OK 1 tests packages/test_game`. This ran only one test; see the note below.
- `tools/mine.sh` on the new test before the lib change: fails to compile, as expected (`tier` undefined, `notATier` undefined, `mapTiers` undefined).
- `tools/mine.sh` after the change: `OK 9 tests packages/test_game`, analyze clean for `packages/test_game`, 4 files formatted.
- `tools/check.sh` was not run (per the brief; the script runs it after the job).

## Values computed for the expectations

- Parse of a map with `"tier": "medium"` gives `tier == 'medium'`.
- Parse of a map with no tier gives `tier == null`.
- `"tier": "extreme"` throws `FormatException` whose message is exactly `"extreme" is not a tier: use easy, medium or hard`.
- `"tier": 7` throws `FormatException` containing `"tier" must be text` (the full message is `Map "x": "tier" must be text, got 7`).
- Two maps differing only in tier (easy vs hard) are not equal; two with the same tier (easy) are equal.
- Schema: `"tier": "hard"` gives no issues; `"tier": "extreme"` gives an issue containing `"extreme" is not a tier: use easy, medium or hard`.
- Template: `tier` is `easy`, which is in `mapTiers`.

## Questions

1. The brief said step 1 should "run the arena suite". I could only run `tools/mine.sh`, which runs the tests whose names match touched files. It ran 1 test after step 1 and 9 after step 2. The full arena suite runs in the post-run `tools/check.sh arena`, so it has not been run by me.
2. `arena_map_parse.dart` has no dartdoc on its private helpers, the same as `arena_map_pieces.dart`. The class doc is unchanged. Say if you want one line on the file.

## Suggestions

- `docs/levels.md` could say that `tier` is optional and that d2b will make every shipped map carry one. I did not touch it, since it is outside the allowed files.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 d2a: Arena maps can say their difficulty tier

Adds an optional "tier" (easy, medium or hard) to an Arena map, read by
fromJson and compared in ==. A map with no tier reads as null, not yet
rated, which d2b fills in. Schema and parser share the words of the
refusal. The parse helpers move to arena_map_parse.dart so arena_map.dart
stays under its size limit; no behaviour changes there.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

d2a done: Arena maps read an optional tier (easy/medium/hard) in the parser, schema and template; parse helpers moved to arena_map_parse.dart. Open: d2b rates every shipped map; no picker or director use yet.

## Delete

- none
