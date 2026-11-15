# b012b-1b-rules-rest: a puzzle file may say "hard", and each level starts its pieces further off

## Summary

Phase 1 of the Hard level is done; the brief's four items are all in.

- **Files may say `"hard"`**: `puzzleLevels`, the schema's enum and message, and
  `tools/level_new.dart`; the two refusal tests now assert acceptance (a made-up
  level `tricky` keeps the refusal path), and `level new` makes a Hard puzzle.
- **The start-angle table**, both functions: Easy 30°, Medium 60°, Hard 90°, capped
  by half the symmetry (square 45°, triangle 60°). The error is picked first, so a
  rectangle reaches 90° where a 50-try loop never did: `leastStartDeg(level, symmetry)`.
- **The 8.5 mm floor is every level's**: `_phoneSize` no longer skips Hard.
- **The picker focuses its first offered level**, not enum index 0.
- **Tests**: new `puzzle_start_table_test.dart` (5, each failing on the old code),
  one host test, four layout tests and the tray-overlap rule test re-pinned.
- **Checks**: format 785 files, 0 changed; analyze clean; puzzle 430 PASS; host 428 PASS.

Numbers that moved: camera boat 4.6574 → 4.6304 and 4.6202 → 4.5934; mirror boat
92.60 → 92.94 wide; tablet 9.671142 → 9.699315 and 7.708168 → 7.661124; the
rules' tray-overlap case 7 issues → 2.

Open: the template's notes and `tools/level.sh` still say `--level easy|medium`
(outside `allow:`, question 1); the library has no Hard puzzle yet (phases 2, 3).

On a device nothing visible changes yet: all 12 puzzles are Easy or Medium, and
only Medium's turned pieces move (60° off now, so the boat lays out slightly
differently). A Hard file shows every non-circle piece 90° off — 45° for a square
and 60° for a triangle, as far as their symmetry allows.

## Self-check (review-rules part A)

1. **Every host setup.** The one host-facing change is the picker's autofocus:
   a TV or PC with a remote, a phone on "Play on this phone" and a phone on
   "Show on this device" all mount the same `ShapeRaceScreen`, whose first
   offered level's "any puzzle" button now takes the focus; a joined phone draws
   its own pad, never this list. An older peer is unaffected (no protocol
   change). `host`: `test/games_screen_levels_test.dart` (a Medium-only library
   focuses `random-medium`), plus `test/games_screen_test.dart` unchanged,
   428 tests PASS.
2. **When kept state starts and ends.** Nothing held, timed, counted or cached is
   added: start angles are a pure function of the puzzle, seed and level, and the
   only new state is the picker's focus request at build, released when the
   screen closes. `puzzle`: `test/puzzle_start_table_test.dart` and the tray
   seeds 0–199 in `test/puzzle_rules_test.dart`, 430 tests PASS.
3. **How a new state combines with the others.** No new pause, wait, block or
   phase: the autofocus is one owner's (the level card's `HostButton`) request
   and combines with none of them; the rules change is a value, not a state.
   `host`: `test/games_screen_test.dart`'s escape/back path and
   `test/games_screen_levels_test.dart` PASS.
4. **Stay in the job's folder.** Only files under `allow:` changed (Files
   changed, below); `dart format --set-exit-if-changed` and
   `dart analyze --fatal-infos` are clean over the whole workspace.
5. **Stop rather than overstep.** No file outside `allow:` was needed; the two
   stale `easy|medium` texts outside it are reported as questions 1, not edited.

## Decisions

- **The level floor is a `switch` function, not a map.** A map lookup is
  nullable and would need a `!`; the switch is total and proves the value.
- **One helper caps the floor: `leastStartDeg(level, symmetry)`.** Both
  functions use it, so "min(level, symmetry/2)" is worded once.
- **`startAngles` picks the error first, then the sign.** The brief's rule; a
  random angle modulo 360 cannot reach 90° for a rectangle in 50 tries.
- **The tray scan uses `least - wholeDegreeSlackDeg` (0.5°).** A tray lays pieces
  at whole degrees, and a target angle that is not whole can put the least just
  out of reach (a Medium square at 45.5° reaches 44.5° at most), where the old
  code would start it at its target. Whole target angles are unaffected: their
  errors are whole numbers, so the 0.5° slack admits no extra degree.
- **`_phoneSize` loses only its Hard skip.** Its doc says the floor is every
  level's, which is what the owner asked for (harder by pieces, never by time).
- **The picker computes the first offered level from the library** and compares,
  instead of tracking an index: index 0 is not the first card shown when Easy is
  missing. It is read with a pattern match on `AsyncData` because riverpod 3's
  `AsyncValue` has no `valueOrNull`.
- **`puzzle_new_test`'s refusal case uses `tricky`.** The refusal message still
  needs a test; `hard` is now the success case.
- **The mirror test's boat-only branch is gone.** Seed 1's boat now reaches the
  board fraction exactly (measured 92.943190 px against the fraction's
  92.943190), so `<=` and `closeTo` are one assertion.

## Computed test values

`test/puzzle_start_table_test.dart` (each failed on the old code; the old floor
was 30° at every level):

| Case | Starts checked | Expected |
| --- | --- | --- |
| Rectangle, Easy / Medium / Hard | 100 seeds × (`startAngles` + both trays) = 300 per level | error ≥ 30 / 60 / 90 |
| Hard square (symmetry 90) and triangle (symmetry 120) | 300 each | error 45 and 60 exactly (±1e-9) |
| Medium triangle at target 45.5° (trays only) | 100 seeds × 2 trays | error ≥ 59.5 = 60 − 0.5; the old floor gave 40.5 |
| A `"hard"` file of 11 turned rectangles, 4 big | once | parses, no `PuzzleRule.level` issue |
| `createLevel(..., level: 'hard')` | once | file says `"hard"` |

Re-pinned layout values (old → new, 4-decimal px and 3-decimal units):

- `camera_test`: boat 4.6574 → **4.6304** at 667 × 375 (4.6304246094);
  4.6202 → **4.5934** at 734 × 372 (4.5933812126). House, rocket and tree
  unchanged.
- `mirror_place_test`: boat mirror 92.60 × 76.34 → **92.94 × 76.62**
  (92.9431901748 × 76.6153324414); the comment's boat scale 4.8810 → **4.8527**
  px per unit (4.8526849907). The boat's mirror now equals the board fraction.
- `tablet_board_test`: solo iPad boat scale 9.671142 → **9.699315**
  (9.6993146141), world top 124.018 → **123.961** (123.9613707718), bottom
  902.702 → **909.471** (909.4709702298); the small iPad 7.708168 → **7.661124**
  (7.6611238964) with world 241.102 / 99.478 / 938.898 / 719.922 (was 237.937 /
  99.384 / 942.063 / 720.016); portrait world top 120.940 → **120.875** and
  bottom 1023.517 → **1031.363** (120.8749457465 / 1031.3632979230) with the
  clock area 173.8 / 1039.363 / 712.424 / 1154.051; landscape split boat
  392.560…973.440 → **395.084…970.916** (395.0841805682 / 970.9158194318); the
  852 × 393 phone's boat solo 203.065…648.935 → **205.002…646.998** and split
  314.532…537.468 → **315.501…536.499**. House is unchanged everywhere.
- `tray_packing_test`: the level's least replaces the bare 30 in the scan and
  the assertion; the boat's mast still starts 90° (tray below) and 0° (beside).
- `puzzle_rules_test` "no two pieces' tray boxes overlap at any start": 7
  issues → **2**, the first now `x/a: at start 13 its tray box overlaps "b"'s`
  (was start 12 and `"d"`).

## Checks run

- `tools/check.sh format analyze puzzle host` cannot be launched in this
  sandbox (the script needs approval), so its four checks were run one by one
  with the same commands: `dart format --output=none --set-exit-if-changed
  controller_app tv_test_app packages assets` — 785 files, 0 changed;
  `dart analyze --fatal-infos` — no issues; `puzzle` `flutter test` — **430
  tests PASS**; `host` `flutter test` — **428 tests PASS**.
- Extra, not in the job's check but the change reaches it:
  `controller_app/test/puzzle_size_test.dart` — 3 tests PASS (Medium's new
  angles leave the 8.5 mm floor happy on every phone it pins).
- `phone` and `tv` suites were otherwise **not run**; neither reads these values
  except through `puzzle_size_test.dart`.

## Files changed

- `packages/puzzle_game/lib/src/puzzle.dart` — `puzzleLevels` takes `hard`; docs
  for `Level`, the parser and `rotated`.
- `packages/puzzle_game/lib/src/start_angles.dart` — `levelStartDeg`,
  `leastStartDeg`, `wholeDegreeSlackDeg`; direct error sampling in
  `startAngles`; the level's least in `compactStartAngles`.
- `packages/puzzle_game/lib/src/puzzle_rule_fit.dart` — `_phoneSize` no longer
  skips Hard; its doc says the floor is every level's.
- `packages/puzzle_game/puzzles/puzzle.schema.json` — `level` enum, error
  message and description take Hard.
- `tools/level_new.dart` — `newPuzzleLevels`, usage and message take Hard (the
  formatter also re-wrapped two calls in the file).
- `packages/puzzle_game/test/puzzle_start_table_test.dart` — new, 5 tests.
- `packages/puzzle_game/test/puzzle_format_test.dart`, `puzzle_schema_test.dart`,
  `puzzle_new_test.dart` — "hard" accepted; an unknown level keeps the refusal
  test; `new` makes a Hard puzzle.
- `packages/puzzle_game/test/camera_test.dart`, `mirror_place_test.dart`,
  `tablet_board_test.dart` — values re-pinned to the new table, comments
  updated.
- `packages/puzzle_game/test/tray_packing_test.dart` — the level's least instead
  of a bare 30.
- `packages/puzzle_game/test/puzzle_rules_test.dart` — the tray-overlap case: 2
  issues, the first at start 13.
- `packages/party_host/lib/src/ui/games_screen.dart` — autofocus on the first
  offered level.
- `packages/party_host/test/games_screen_levels_test.dart` — new, 1 test.
- `docs/levels.md` — the `level` field and the turning paragraph carry the
  table and `"hard"`.
- this report.

## Questions

1. `packages/puzzle_game/puzzles/_template.json`'s notes and `tools/level.sh`'s
   usage (lines 4 and 46) still say `--level easy|medium`; both are outside this
   job's `allow:`. May a follow-up update them?
2. The library still has no Hard puzzle, so `docs/levels.md` says so; is that
   planned for phase 2 or 3?
3. `startAngles` can now return an angle above 360 before the `% 360` (target
   plus a positive error); the old loop could too. Left as is.

## Commit message

```
Puzzle: files may say hard, and each level starts its pieces further off

puzzleLevels, the schema and tools/level_new.dart take "hard"; the tests
that asserted the refusal now assert it is accepted, and a made-up level
keeps the refusal path tested.

start_angles.dart starts a turned piece at a random error from its level's
least — Easy 30, Medium 60, Hard 90 — up to half its symmetry, so a square
starts 45 off and a triangle 60. startAngles picks the error first, since a
random angle never reaches 90 for a rectangle; the tray scans whole degrees,
half a degree under the least for a target angle that is not whole.

_phoneSize no longer skips Hard, so the 8.5 mm floor applies to it. The
picker focuses the first level it offers, not enum index 0. Medium's 60
floor moves four layout tests and two rule-test numbers.
```

## Status row

`- B-012b phase 1 done: a puzzle file may say "hard" (parser, schema, level new), the start-angle table (Easy 30 / Medium 60 / Hard 90, capped by symmetry), Hard's 8.5 mm floor, and the picker focusing its first offered level. Open: Medium's limits and split-screen files (phase 2), a Hard puzzle in the library, `_template.json` and `tools/level.sh`'s usage still say easy|medium.`

## Delete

- none
