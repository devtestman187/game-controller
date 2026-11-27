job: board3m g3t — board model: one targeted gate per night, no fixed gates, no rival block
stop: no rules, no CityRules change, no simulator; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/board.dart:1-168 · packages/party_host/test/city/board_test.dart:1-30 and 78-100 and 150-194 · owner Nov 27 (final): "The fixed tile-4 gates are removed. The winner of the mid-night gate game picks one rival; the gate goes on that rival's next unbuilt tile. One gate per night. Roadworks: own road only (the rival block is removed)."
changes: Board (constructor loses gates · gates · gatesOpen · openAllGates; gains gate · gateOpen · placeGate · openGate) · RoadworksBlock (removed) · Gate (kept: roadId, tileIndex, kind) · GateKind (kept)
model: haiku
turns: 35
expected-min: 25
tests-first: exempt the new gate tests need the new API
do:
1 Tests first (board_test.dart). Replace the fixed-gate helper and tests: the board builds without gates; no use of CityRules gateTileIndex (it is being removed: use a literal tile index). New cases: gate is null and gateOpen false at the start; placeGate sets gate; a second placeGate throws StateError (one gate per night); placeGate throws ArgumentError for a road not on the board and for tileIndex below 0 or at/above the road's length; openGate throws StateError with no gate, else gateOpen becomes true and the gate stays; a new Board has no gate. Delete the RoadworksBlock test.
2 board.dart: delete RoadworksBlock and the `gates` parameter, `gates`, `gatesOpen`, `openAllGates`. Add `Gate? get gate`, `bool get gateOpen`, `void placeGate(Gate gate)`, `void openGate()` as in the tests. A gate may stand on any tile of a road (the Plaza tile too: the next unbuilt tile can be the last). Update the library doc comment (no roadworks block, one gate per night on a rival's next unbuilt tile, set by the night).
3 Run `flutter test packages/party_host/test/city/board_test.dart`, `dart format` and `dart analyze` on both files; fix every info, warning and error.
4 Report: the new API and the test names.
allow: packages/party_host/lib/src/city/board.dart · packages/party_host/test/city/board_test.dart
check: format analyze host
report: docs/briefs/m17/board3m/g3t-report.md
