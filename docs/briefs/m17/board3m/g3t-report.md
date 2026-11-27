# board3m g3t: one targeted gate per night

## Summary

- Board no longer takes gates. The fixed per-corner gates and `openAllGates` are gone.
- New single night gate: `Gate? get gate`, `bool get gateOpen`, `void placeGate(Gate gate)`, `void openGate()`.
- `RoadworksBlock` is deleted (no other file used it; the rival block is removed).
- `Gate` and `GateKind` are unchanged.
- Tests: the fixed-gate tests and the RoadworksBlock test are removed; new Board gate tests use a one-road board
  (`north`: tiles n1, n2, Plaza np, so indices 0-2 are valid) and literal tile indices, with no `CityRules.gateTileIndex`.
- `tools/mine.sh` result: format ok (6 files), analyze ok for packages/party_host, `OK 79 tests packages/party_host`.
  The analyze info (`prefer_const_constructors` at board_test.dart:87) was fixed and the run repeated.

## Decisions

- `placeGate` checks the road and tile index first (ArgumentError), then the one-gate rule (StateError). A refused
  call therefore leaves the board unchanged, and a test shows the gate stays null.
- A gate may stand on the Plaza tile (index == road.length - 1). Index == road.length is refused.
- The `Board` constructor keeps the district-id and tile-id uniqueness checks and drops the gate checks.
- `_roadOf` is a private linear search over `districts`. Boards are small, and a map would add state to keep in sync.
- `openGate` with no gate throws StateError rather than silently doing nothing.

## Self-check (review-rules part A)

1. Host setups: model only, no host UI touched. Covered by no test; nothing in the host calls the new API yet.
2. Kept state: the gate and the open flag live on one Board, which is one night. A new Board starts with no gate and a closed
   gate (`a new board has no gate, and the gate is closed`).
3. Combinations with pause, away, get-ready, dropped link, results, leaving: not applicable at model level; the gate game
   that calls `placeGate` is not wired in this job.
4. Stayed inside allow: only board.dart, board_test.dart and this report.
5. Nothing stopped. (The brief's "tests first" is not run as a fail-first check; see Questions.)
6. Looks: none; no widget changed.

## Tests (names in board_test.dart)

- `a new board has no gate, and the gate is closed`
- `placeGate sets the gate on its road and tile`
- `placeGate accepts the Plaza tile, the last tile of the road`
- `a second placeGate in the same night throws StateError, and the first gate stays`
- `placeGate throws ArgumentError for a road that is not on the board, and places nothing`
- `placeGate throws ArgumentError for a tile index below zero or at the road length`
- `openGate with no gate placed throws StateError`
- `openGate opens the placed gate for every player, and the gate stays`
- Kept: `accepts districts whose district ids and tile ids are all unique`, the three refusal tests for ids, and
  `keeps every tile id unique with a lane beside each corner`.

## Questions

1. The brief's `stop:` line says "never tools/mine.sh", but its `check:` line, the owner's instructions and the worker rules
   name tools/mine.sh. I ran tools/mine.sh and did not run `flutter test` directly.
2. The brief says `tests-first: exempt`, but the new gate tests were written with the new API. I did not run them against the
   old code, so the fail-first property is not shown.
3. The git status at the start already showed rules.dart, roadworks_offer_test.dart, rules_test.dart and tools/sim/sim_rules.dart
   as modified. I did not touch them. tools/mine.sh reports "6 file(s) formatted"; I did not check whether it changed those files.
4. `CityRules.gateTileIndex` still exists in rules.dart. The brief says it is being removed, but that is outside this job.

## Suggestions

- Remove `CityRules.gateTileIndex` in the job that owns rules.dart, once nothing refers to it.

## Commit message

board3m g3t: one targeted gate per night on the board

Remove the fixed per-corner gates and openAllGates from Board, and delete RoadworksBlock.
Board now takes a single night gate through placeGate (one per night, on any tile of a
road, the Plaza included) and opens it with openGate. The mid-night gate game will call these.
Tests use a one-road board with literal tile indices.

## Status row

- m17 board3m g3t: Board has one night gate (placeGate, openGate, gateOpen); fixed gates and RoadworksBlock removed. Open: the gate game that places the gate on a rival's next unbuilt tile, and CityRules.gateTileIndex removal.

## Delete

- none
