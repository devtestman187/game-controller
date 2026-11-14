# Review: b015-routes

## Summary

Verdict: **small fixes**. 0 must, 1 should, 3 could. The commit (33f206a) is 5 files, all in the job's
folder: the report, two `*.race.json` snippets and two PNGs; nothing under `packages/` or `docs/design/maps/`
moved, the brief's numbered items are all answered, and every brief number I re-derived is right (goal 12.0 ×
10.08 units, west gate 12.85 units between wall faces, the 0.91-unit shortfall, the 10.425-unit top-gate
opening).

What matters most:
1. report:60 says the top and bottom keep gates "travel 24.0" — they travel 12.0 units (`block-castle.json:39-40`).
2. report:129-132 lists four files for deletion that do not exist in the commit or the folder.
3. The play figures (1.82 s, 2.23 s, arrows of 97.5 and 139.4 units) have no saved transcript, so no one can
   recheck them.

## Findings

- **should** docs/briefs/m14/bugs6/b015-routes-report.md:60 "the top and bottom gates' bars are 24.0 long and travel 24.0" is wrong on travel: the movers at `packages/test_game/maps/block-castle.json:39-40` go from x 0.5 to 0.575 and 0.5 to 0.425, i.e. 0.075 × 160 = 12.0 units, and only 12.0 gives the 10.425-unit opening the same sentence reports. → write "travel 12.0".
- **could** docs/briefs/m14/bugs6/b015-routes-report.md:131 the Delete section names `block-castle-original.json` and `toy-factory-original.json`, and line 129 the two temporary tests, but none of the four is in commit 33f206a (5 files) or in `docs/briefs/m14/bugs6/b015-routes/` (4 files), so the list is stale. → list only what is still on disk, or `none`.
- **could** docs/briefs/m14/bugs6/b015-routes-report.md:104 self-check 4 quotes `git status --porcelain` as showing only the job folder new, but the tree now also shows modified `tv_test_app/windows/flutter/generated_plugin_*` and untracked `docs/briefs/m14/bugs3/*.patch` (not from this commit, which is clean). → scope the line to the commit or to the paths the job owns.
- **could** docs/briefs/m14/bugs6/b015-routes-report.md:15 the play numbers (1.82 s, 2.23 s, one hazard hit, arrows 97.5 and 139.4 units) come from a steering test the brief requires deleted, and the report keeps no output of it. → save the run's printed numbers and waypoints as a text file beside the PNGs.

## Decisions to confirm

- The Block Castle goal inside the keep: the rule book's way in is the keep's west gate, which the rule book can
  use only because `MapGrid` ignores movers by default (`packages/test_game/lib/src/map_grid.dart:30`), while
  decision 2 shows that gate never admits a marble. The owner should accept the top-gate timing finish or move
  the goal to the courtyard (question 1).
- Landing a race makes these maps appear in the race list as well as the Bumper list (`packages/party_host/lib/src/ui/arena_map_choice.dart:18`), so the change touches the party-night §7b "Bumper Round only" rule the report calls landing work for `four_maps_test.dart` — worth an explicit owner yes.
- The race's four starts sit 0.14 apart (2.2 marbles) while the Bumper Round's rule is 3 (`map_rules.dart:76`); the race rule checks no spacing (`map_rule_race.dart:9`), so the report's question 3 should be settled as a rule-book change or a written exception.

## Could not check

- That the rule book and the steering runs pass: the map files are back to their start and the temporary tests are deleted, so I could not re-run either; I re-derived the geometry from the map files and the mover/field code instead, and it agrees with the report apart from the travel figure above.
- Which start slot the arrow's white marker covers in the PNGs: at 664 × 952 I can see three green dots and the marker in the start column, but not whether the fourth dot is under it at slot 0 (y 0.5) or the marker sits at slot 3.
- "Could not run `tools/level.sh check`" is the report's own excuse and I cannot tell whether the sandbox refused it; the equivalent `flutter test --dart-define=mapId=… test/map_check_test.dart test/map_schema_test.dart` is 4 tests (1 + 3), matching the count claimed.
- My attempt to read the PNG's pixels left one scratch file outside the repo, `E:\tmp\b015r\scan.dart` (the permission system blocked deleting it); no repo file was touched.

## Commit message

Review b015-routes: gate travel, stale Delete list, play figures

Checked the b015 commit against the coding guidelines, the review
rules and its brief: 5 files, all in the job folder, nothing under
packages/ or docs/design/maps/, every brief number re-derived.
One should finding: the top and bottom keep gates travel 12.0 units,
not the 24.0 the report's decision 2 states (the 10.4-unit opening it
derives is right). Three could findings: the Delete section names
files that no longer exist, self-check 4's git status line no longer
holds, and the play figures have no saved transcript. Decisions to
confirm: the goal behind a timing gate, the maps joining the race
list, and the 0.14 start spacing against the bumper's 3-marble rule.

## Status row

- **b015-routes**: reviewed — the commit is inside the job folder and every reported measurement checks out except one gate-travel figure; **open**: the owner's approval of the two pictures, the landing job (both map files with their `notes`, `four_maps_test.dart`, the two `docs/design/maps/` sheets), and the owner's answers to the report's four questions.

## Delete

- none
