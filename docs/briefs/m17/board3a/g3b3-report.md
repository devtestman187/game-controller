# board3a g3b3 report

## Summary

- Done: shared final place in `rankFinal`, `driveCost` always 0 with `canDriveOnto`, `assignStarts` (new), and the `Board.gatesOpen` dartdoc.
- Blocked: the kids step. The kids preset was removed in g3b2 (see `g3b2-report.md`, decision 1), and no code decides whether roadworks is offered, so there is no "one place" to add the check. I added no kids flag, because a flag nothing reads is dead code. Needs a decision (question 1).
- Checks: `tools/mine.sh` reported `OK 49 tests packages/party_host` and `RESULT: ok` (format, analyze, touched tests).
- Fail-first not shown: I wrote the new tests and the code in one pass and did not run the tests before the code change, so I did not see them fail. `tools/mine.sh` was the only run.

### Decisions

1. `driveCost` keeps its signature `({required bool onBuiltRoad, required CityRules rules})` and returns 0. The parameters are now unused. I kept them so the test contract and any caller stay the same. See question 2.
2. `rankFinal` now returns `List<FinalPlace>` (a new typedef `({String playerId, int place})`), not a list of ids. The brief asked for shared places, and a plain id list cannot show them. The only caller is the test file.
3. `assignStarts` takes the corner ids from a new top-level `const startCorners` in `rules.dart`. Lane ids are built as `'$corner-lane'`, the convention `board_test.dart` already uses. More players than the 8 starts throws `ArgumentError`; the brief did not say what to do then.
4. Existing `rankFinal` tests were moved to the record form. The old "tied players keep the order given" test was replaced by the shared-place test, because that is the new rule.

## Changed files

- `packages/party_host/lib/src/city/rules.dart`
  - `FinalPlace` typedef (new).
  - `rankFinal`: returns places with standard competition ranking; dartdoc adds "ranking only at the final stop; an early arrival keeps its place but does not end the night."
  - `driveCost`: returns 0 always; dartdoc updated.
  - `canDriveOnto(bool builtTile)` (new): returns `builtTile`.
  - `startCorners` (new const) and `assignStarts` (new).
- `packages/party_host/lib/src/city/board.dart`
  - `Board.gatesOpen` dartdoc: gates stay open for the night; a new night builds a new `Board`; no reset method.
- `packages/party_host/test/city/rules_test.dart`
  - `driving` group (replaces `driveCost` group): four tests for `driveCost` and `canDriveOnto`.
  - `rankFinal` group: the three existing tests now expect records; the tie-order test is replaced by "players tied on arrival, distance and Bolts left share a place, then the next place skips past them".
  - `assignStarts` group (new): "the first four players start on the corners, in slot order"; "players 5-8 start on the second lane beside each corner, in the same order"; "more players than there are starts is rejected".
- `packages/party_host/test/city/board_test.dart`: not changed (nothing in the brief needed a board test).

## Test names and values seen

- `rankFinal` tie: players first and second tied (not reached, distance `gateTileIndex` = 4, Bolts 0), third at distance 3, Bolts 0 → places `1, 1, 3`.
- `assignStarts` with 8 players: `p1..p4` → `cog-hill, candy-harbour, pepper-park, lantern-ridge`; `p5..p8` → `cog-hill-lane, candy-harbour-lane, pepper-park-lane, lantern-ridge-lane`.
- `assignStarts` over capacity: `startCorners.length * 2 + 1` = 9 players → `ArgumentError`.
- `driveCost`: 0 for built and unbuilt tiles; `canDriveOnto(true)` true; `canDriveOnto(false)` false.

## Checks

- `tools/mine.sh` → `OK 49 tests packages/party_host`, `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- Not run: the brief asked for explicit `dart format`, `dart analyze` and `flutter test <file>` runs and said not to run `tools/mine.sh`. The top-level instructions asked for `tools/mine.sh`; I followed those. Analyze was done by mine.sh.
- `tools/check.sh` not run, as instructed.

## Self-check (review-rules part A)

1. Host setups: this change is pure rules and has no host wiring; it is covered by the unit tests only.
2. Kept state: none added.
3. Combination with pause, away, "Get ready", drop, results, leave: not applicable; no host wiring (M17b).
4. Stayed inside the allow list.
5. Stopped rather than overstepped on the kids step (question 1).
6. Looks: none changed.

## Questions

1. Kids: where is roadworks decided, and should a kids flag come back? The preset was removed in g3b2, and no code offers or blocks roadworks, so the brief's "one place" does not exist. I need a decision before adding it.
2. `driveCost` ignores both its parameters now. Drop them (and update the four callers/tests), or keep the signature for a later caller?
3. `CityRules.roadworksCost` is no longer read by anything in `lib/`. Remove it, or keep it for a later job?
4. Are the start corner ids `cog-hill`, `candy-harbour`, `pepper-park`, `lantern-ridge` and the `-lane` suffix the final ids? They match `board_test.dart`, but the PRD was not checked.
5. More than 8 players: is `ArgumentError` right, or should the caller cap the party size?
6. The brief said "never tools/mine.sh" and "run dart format, dart analyze and flutter test by explicit path", while the top-level instructions said `tools/mine.sh` only. I followed the top-level instructions.
7. Fail-first: the brief asks that the new tests fail on the old code. I did not check that, because I wrote the code in the same pass. A re-run against the old code would need a checkout, which is not allowed here.

## Commit message — a draft

city: shared final place, driving rule and start assignment

- rankFinal gives tied players one place (standard competition ranking: 1, 1, 3)
  and says the final ranking happens only at the last stop.
- driveCost is always 0; canDriveOnto(builtTile) says a token drives only onto built tiles.
- assignStarts maps players in slot order to the four corners, then to their lanes.
- Board.gatesOpen dartdoc: gates stay open for the night; a new night builds a new Board.
- Kids roadworks rule not done: no code decides roadworks, so there is no place to add it.

## Status row

board3a g3b3: done — shared final place, driveCost 0 with canDriveOnto, assignStarts, gatesOpen dartdoc; 49 host tests pass. Open: kids roadworks rule (no decision point in code), driveCost unused params, roadworksCost unused.

## Delete

- none
