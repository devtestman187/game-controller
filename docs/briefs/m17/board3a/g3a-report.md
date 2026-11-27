# board3a g3a report: City Rush board model as pure Dart types

## Summary

Added the City Rush board data types in one new file, with tests written first in a new test file.

- `packages/party_host/test/city/board_test.dart` (new, 82 lines): written first; it failed to compile (`Undefined name 'GateKind'`) before the lib file existed.
- `packages/party_host/lib/src/city/board.dart` (new, 103 lines): `Tile`, `Plaza` (a `Tile`), `District` (validates a non-empty road ending at a `Plaza`), `Token` (playerId, tilePosition, absent), `Bolts` (per-player map, `of` gives 0 for unknown players), `RoadworksBlock` (tileId), `GateKind` (brokenBridge, potholeField, riverFerry), `Gate` (kind, closed at start, one shared `opened` flag, `open()`).
- Pure Dart: no Flutter, no `night/` or host-service imports.

Test counts seen in this job: `flutter test packages/party_host/test/city/board_test.dart` -> "All tests passed!", 11 tests (+11 -0).

Checks:
- `dart format` on both files: 0 changed.
- `dart analyze` on both files: "No issues found!" (no infos, warnings or errors).
- `tools/mine.sh`: "RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested". It checked nothing, because the new files are untracked. This is the problem the brief's repair note described; the three commands above are the real checks.

Decisions:
- Kept every type in `board.dart`, as the brief's `changes:` line says. The worker rules ask for one public type per file; this is a conflict and needs a decision (see Questions).
- `Plaza` is a `Tile` subclass, so a road is `List<Tile>` and "ends at the Plaza" is checked with `road.last is Plaza`.
- `Gate` exposes `open()` as the only way to change `opened`. It is a state change with no rule attached; the brief named no other way.

## Self-check (review-rules part A)

1. Host setups: not applicable. The types are pure data with no host wiring; no screen or host setup is touched.
2. Kept state: `Gate._opened` starts `false` (`Gate starts closed`) and is changed only by `open()` (`Gate has one opened flag that every player sees`). No other state is kept.
3. Combination with pause, away, "Get ready", dropped link, results, leaving: not applicable; no game flow is added.
4. Folder and allow: only the two allowed files plus this report.
5. Stopped rather than overstepped: nothing blocked. The one-type-per-file conflict is raised as a question instead of splitting files outside `allow:`.
6. Looks: not applicable; no widgets.

## Commit message — a draft

City Rush: add board data types as pure Dart

Add District, Tile, Plaza, Token, Bolts, RoadworksBlock and Gate
(GateKind brokenBridge, potholeField, riverFerry) under party_host
src/city. A District needs a non-empty road ending at the Plaza, and
a Gate starts closed with one opened flag shared by all players.
No rules, numbers or host wiring yet; the tests are written first.

## Status row

board3a g3a: done — City Rush board types (District, Tile, Plaza, Token, Bolts, RoadworksBlock, Gate) in src/city with 11 passing tests. Open: rules, draft, bots and the host adapter are not started; the one-type-per-file question is unresolved.

## Questions

1. The worker rules say one public type per file, but the brief puts all seven types in `board.dart`. Keep it in one file (as briefed) or split it? Splitting needs more files added to `allow:`.
2. The brief's `Gate(kind, opened, shared)` lists `shared` as a constructor field. I modelled sharing as the single `opened` flag with no separate field. Should a `shared` flag exist?
3. `Token.tilePosition` is not checked against the road length. Should the token be validated against its district, or is that for the rules job?
4. The repair note expected an analyzer finding at `board_test.dart` line 82 col 21. Line 82 is the closing brace of `main`; the analyzer reported nothing, so the expected finding did not occur.

## Delete

- none

## Hand-over

Lib and test files are written and green under `flutter test` and `dart analyze`. Nothing is staged. `tools/mine.sh` cannot see untracked files and checked 0 files; the runner should check these two paths once they are tracked.
