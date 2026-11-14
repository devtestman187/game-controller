# b015 race routes: Block Castle and Toy Factory

## Summary

Two race candidates are drawn for the owner to approve. No map ships: `packages/test_game/maps/` and
`docs/design/maps/` are byte-identical to the start (hashes below).

- **Block Castle**: `"race": {"start": [0.075, 0.5], "goal": [0.4625, 0.444, 0.5375, 0.556], "swapSides": true}`
  — the brief's numbers, unchanged; rule book and schema pass (4 tests).
- **Toy Factory**: `"race": {"start": [0.1, 0.5], "goal": [0.88, 0.14, 0.97, 0.24], "swapSides": true}`
  — the brief's numbers, unchanged; rule book and schema pass (4 tests). No rule failed, so nothing changed.

Pictures: `b015-routes/block-castle-race.png` and `toy-factory-race.png` (2x). Sunny = the round the file
reads, Night = the round that swaps sides, the field mirrored as the game mirrors it; four start dots, the goal
rim and one bold arrow along the proposed way. Both ways are clear on the rules' own marble grid and both races
play end to end with a steering bot: 1.82 s (Block Castle) and 2.23 s (Toy Factory), one hazard hit each, the
same either way; the arrows are 97.5 and 139.4 units.

| | Block Castle | Toy Factory |
| --- | --- | --- |
| start (x, y) | 0.075; four at 0.14 apart | 0.1; four at 0.14 apart |
| goal pad | 12.0 × 10.1 units, in the keep | 14.4 × 9.0 units, top-east bay |
| shortest way per start (units) | 68.0 / 72.2 / 72.2 / 84.1 | 135.6 / 133.5 / 138.8 / 132.5 |
| narrowest gate on the way | 12.85 units = 2.23 marbles | open floor |

**The one thing to look at:** Block Castle's finish is inside the keep, and the keep's west and east gates never
admit a marble (0.91 units short at their widest), so the arrow enters by the top gate, which opens to 1.8
marbles for a third of its 3 s cycle. Steering straight at the goal, a marble presses at the shut gate for the
full 60 s. Toy Factory's open floor lets the shortest way be a near-straight diagonal; the arrow follows the
brief's description, but nothing forces it. Adding a race also fails `four_maps_test.dart`'s "Bumper Round
only" test and changes both maps' sheets in `docs/design/maps/`; the landing job must do both.

## What I ran, and how

- `tools/level.sh check <id>` itself could not be run: the sandbox refused to run the script. I ran its exact
  commands: `cd packages/test_game && flutter test --dart-define=mapId=<id> test/map_check_test.dart
  test/map_schema_test.dart` — 4 tests, all pass, for each map, with the race section temporarily in the file.
- There is **no race-play test that reads a map file**: `arena_test.dart` plays `support/maps.dart`'s testMap and
  `arena_bumper_test.dart` plays `ArenaMap.playroom`. So I wrote a temporary steering run (player 'a', 60 fps,
  60 s cap, steering along the proposed way, nudging up out of a corner as a player would) — results in the table.
- The temporary map edits are reverted; sha256 of `packages/test_game/maps/block-castle.json` is
  `10c28e4f…7c33b46e` and of `toy-factory.json` `44227011…7ab02bf1`, both as at the start (re-checked after the
  restore). `git status --porcelain` shows nothing under `packages/test_game/maps/` or `docs/design/maps/`.
- Pictures: `test/support/map_sheet.dart` draws a field, its starts and its goal, but no route, so a temporary test
  (outside allow, deleted at the end; listed under Delete) drew the panel and a route arrow over it and wrote the
  PNGs at 2× with `capturePng`. The panel is the same widget the design sheet uses, so the field cannot drift
  from play.
- `four_maps_test.dart` with the two race sections in place: the library rule check and the bumper fairness test
  pass; only "each new map plays the Bumper Round only: no race section" fails, as it asserts `race == null`.
- `tools/check.sh format`: PASS (3 s).

## Decisions

1. **The arrow is the proposed way, not the rule book's shortest way.** On Block Castle the shortest way runs
   through the keep's west gate, which never opens; drawing that would show a race that cannot be run. Both
   proposed ways are checked clear on `MapGrid` (the rules' own marble-sized grid) point by point, 0.5 units apart.
2. **The west and east keep gates never admit a marble.** The gate is 16.0 units between wall faces; the bar is
   16.0 long and travels 8.0, so at its farthest its tip stands 0.91 units too close to the wall block for a
   marble's centre to fit (it needs 4.455 units from the bar's line and 2.88 from the wall block). The top and
   bottom gates' bars are 24.0 long and travel 24.0, so they open half a gate (10.4 units between faces).
3. **The brief's numbers are kept as written**, since both maps pass every rule; the only correction is the
   arrow's way in the picture (Decision 1).
4. **Sunny = the file's round, Night = the swapped round**, with the night field built as a mirrored map in the
   temporary test (walls, hazards, pieces, starts and goal mirrored, mover angles 180 − deg). That is how the game
   draws a round that swaps sides (`ArenaFieldRules._mirror`), so the picture shows what a player sees.
5. **Nothing in `packages/` or `docs/design/maps/` is left behind**, and the race sections are saved paste-ready
   as `block-castle.race.json` and `toy-factory.race.json`: replace the map's closing `}` with `,` and the
   `"race": {…}` line, or paste the object after `"bumper"`.
6. **The candidate's `notes` line is not part of the snippet.** Both map files say "No race section."; the
   landing job must change that sentence in both files (I did not, since no map ships from this job).

## Questions

1. Block Castle's finish inside the keep is a timing gate: only the top and bottom keep gates ever open, to 1.8
   marbles for about a third of a 3 s cycle. Is that the difficulty you want, or should the goal move to the
   courtyard (e.g. `[0.425, 0.4, 0.575, 0.6]`, the courtyard side of the keep's gates)?
2. On Toy Factory's open floor the shortest way is a near-straight diagonal; the belts and the two walls do not
   force the loop. Do you want it left open (a sprint), or a later job that adds walls to shape the race?
3. The race's four starts sit 0.14 apart (2.2 marbles), under the Bumper Round's 3-marble rule, and on Block
   Castle all four funnel through one 2.23-marble castle gate. Bumping at the start is likely; is that fine for a
   race, or should the race's start spacing become a rule-book check?
4. Landing a race needs `four_maps_test.dart`'s "Bumper Round only" test changed and both maps' sheets in
   `docs/design/maps/` re-rendered (the sheet then draws the start pad and goal). Confirm both are in the landing
   job (I did neither).

## What the owner should try on a device

- Block Castle: race it with 2–4 players and feel the finish: whether entering the keep through the top gate
  reads as fair or as a lucky gap, and whether the courtyard's three cannonballs leave enough room to line up.
- Toy Factory: race it and say whether the sprint across open floor feels like a race or a straight line, and
  whether the bay's rim (crate hazard at y 0.16 and the field edge at x 0.97) traps a marble.
- Both: look at the two PNGs first; the start dots are all on one x, so four marbles leave from one column.

## Self-check (review-rules.md part A)

1. **Every host setup** — not affected: pictures and a rule-book run only; no app, game, protocol or host code
   changed (no test runs a view; nothing ships from `packages/`).
2. **When kept state starts and ends** — not affected: nothing is held, timed or remembered. The only state is the
   temporary map edit, reverted (sha256 re-checked).
3. **How a new state combines with the others** — not affected: the candidate race section's effect on the two
   modes is what the rule book checks (`mapId=…` rule book + schema, 4 tests each, passing); it touches no pause,
   away, ready or results state.
4. **Stay in the job's folder** — `git status --porcelain`: only `docs/briefs/m14/bugs6/b015-routes/` is new
   (plus the two temporary test files, listed for deletion); `packages/test_game/maps/*.json` hashes equal the
   start's.
5. **Stop rather than overstep** — no file outside `allow:` was changed in the end; the temporary map sections and
   the two temporary tests are reverted/deleted, and I did not run `tools/level.sh render`, because it writes
   `docs/design/maps/`.

## Commit message

Draw the two race routes for the owner to approve (B-015)

Block Castle and Toy Factory each get a race candidate, drawn as a 2x
picture in Sunny (the file's round) and Night (the round that swaps sides,
field mirrored), with the four starts, the goal and an arrow.
Both pass the map rule book unchanged: no number was adjusted.
The Block Castle finish is inside the keep, whose west and east gates
never admit a marble; the arrow enters by the top gate, and the report
gives the measured gaps, the play runs, four questions and the landing
work (four_maps_test, the two sheets in docs/design/maps/).

## Status row

- **b015-routes**: the Block Castle and Toy Factory race candidates are drawn (`docs/briefs/m14/bugs6/b015-routes/`) and both pass the map rule book unchanged; **open**: the owner's approval, then landing them in the two map files (with the `notes` line), `four_maps_test.dart`'s "Bumper Round only" test and the two re-rendered `docs/design/maps/` sheets, plus the owner's answer on Block Castle's timing finish.

## Delete

- packages/test_game/test/b015_race_pictures_test.dart
- packages/test_game/test/b015_race_play_test.dart
- docs/briefs/m14/bugs6/b015-routes/block-castle-original.json
- docs/briefs/m14/bugs6/b015-routes/toy-factory-original.json
