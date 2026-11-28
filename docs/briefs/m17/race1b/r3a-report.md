# r3a report: PresentState in the match snapshot, with the 2 KB check and an older-peer test

## Summary

- Added `PresentState` (holder, fuse left, fuse total, popped) as a new public class, with `toJson` as a 4-number list, `fromJson`, `lerpTo`, `==`, `hashCode`, `toString`.
- `MatchSnapshot` gained `present` (a `PresentState?`), written as JSON key `pr` only when non-null, read back when the key is there, and lerped like `cat` (both frames: lerp; one: the nearer frame's).
- `PuzzleSnapshot.version` and `MatchSnapshot.version` stay 2; an old peer ignores `pr` and decodes the rest.
- The existing `nightFrame` in `snapshot_eight_players_test.dart` now carries a present, so its 4-player byte test measures a frame with a present.
- New `present_snapshot_test.dart`: 10 tests (round trips, popped encoding, older peer without `pr`, unknown key `zz`, lerp values, match lerp with both and one present, the 40-byte budget at 4/6/8 players, the 4-player frame under `maxBytes`).
- `tools/mine.sh`: format OK (5 files), analyze OK (package `puzzle_game`), tests OK (500 tests, package `puzzle_game`).

## Files changed

- `packages/puzzle_game/lib/src/present.dart` (new, 53 lines): the `PresentState` class with dartdoc. The `lerpTo` switch at halfway uses a bare `0.5`, the same as `cat`'s line in `snapshot.dart`.
- `packages/puzzle_game/lib/src/snapshot.dart` (354 to 364 lines): import of `present.dart`; `this.present` in the constructor; field with dartdoc; `'pr'` in `toJson` (only when non-null); `present:` in `fromJson` (absent key = null); `present` in `lerpTo` (both: lerp; one: nearer frame's), with locals `pa` and `pb`.
- `packages/puzzle_game/lib/puzzle_game.dart`: `export 'src/present.dart';` between `points.dart` and `puzzle.dart`.
- `packages/puzzle_game/test/snapshot_eight_players_test.dart`: `present: PresentState(holder: left, fuseMs: 12345, fuseTotalMs: 15000)` added to `nightFrame`.
- `packages/puzzle_game/test/present_snapshot_test.dart` (new): the tests listed below.

## Tests and values computed

- Byte cost of a present, computed by hand (not measured by a run): `,"pr":[1,12345,15000,0]` is 23 bytes at the frame's worst-case digits. The test asserts at most 40 at 4, 6 and 8 players, so it passes with the 40 bytes allowed; the test does measure the real difference per player count.
- Lerp values (from `fuseMs` 1000, `fuseTotalMs` 4000, left, not popped; to `fuseMs` 3000, `fuseTotalMs` 6000, right, popped):
  - t 0.25: fuse 1000 + 2000 × 0.25 = 1500, left, total 4000, not popped.
  - t 0.5: fuse 2000, right, total 6000, popped (the switch happens at 0.5).
  - t 0.75: fuse 2500, right, total 6000, popped.
- Round trips: the frame with a present decodes to the same present and re-encodes to the same string; a frame without one decodes with none.
- Older peer: the frame's map with `pr` removed decodes; its boards (compared as `toJson` maps), seed 7 and cat equal the frame without a present; `present` is null. A map with an extra `zz: 1` key decodes its present.
- Runs: `tools/mine.sh` → `OK 500 tests packages/puzzle_game`; `RESULT: ok: 5 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.

## Self-check (review-rules part A)

1. Host setups: this is a data-contract job with no host screen; the frame shape is what every host sends and reads. Covered by the round-trip and older-peer tests (`present_snapshot_test.dart`).
2. Kept state: the present is absent (null) when it is away; the round-trip "without a present" test shows a frame with none.
3. Combination with the pause menu, away host, dropped link, results and leaving: not applicable in this job (no rules, no painter, no `match.dart` change). The only combination tested is with the cat and the boards in the same frame.
4. Stayed inside `allow:`: yes, the 6 files in the brief plus the report.
5. Stop rather than overstep: nothing stopped.
6. Looks: no UI change; no look-sized widget.

## Decisions

- `nightFrame` is imported from `snapshot_eight_players_test.dart` with `show nightFrame, playerCounts` rather than copied. The brief allowed either; import avoids a 60-line duplicate.
- `cat_snapshot_test.dart` was left unchanged: the brief lists it in `allow:` but its steps name no edit to it.
- The new file's tests are exempt from tests-first (the test file cannot compile before the class exists, as the brief says).

## Questions

1. The `0.5` in `PresentState.lerpTo` and in the `pr` line of `MatchSnapshot.lerpTo` is a bare literal (the cat line does the same). Should both name it (for example `PresentState.halfway`)? I followed the cat line to keep the two alike.
2. Should `cat_snapshot_test.dart`'s night frame get the same present as `nightFrame`, so the cat test measures the full worst case? The brief doesn't ask for it.
3. The 23-byte figure is by hand; a `LOAD8=1 bash tools/load8.sh` run would measure the real byte counts at 4, 6 and 8 players.

## Commit message — a draft

```
Add PresentState to the match snapshot, with a 40-byte budget

The present's holder, fuse and pop travel in the match snapshot as
key 'pr', written only when a present is out. Older peers ignore
the key and decode the rest; the version stays 2. The present lerps
between frames like the cat: holder and pop switch at halfway, the
fuse runs down linearly. A test holds a present to 40 bytes at 4,
6 and 8 players and keeps the 4-player night frame under 2 KB.
```

## Status row

M17 r3a: done. `PresentState` (holder, fuse, popped) is in `MatchSnapshot` as `pr`, with lerp and older-peer and 40-byte tests. Open: byte counts at 6 and 8 players are by hand (23 bytes), not measured by load8; `cat_snapshot_test.dart` doesn't carry a present.

## Delete

- none

## Hand-over

- Nothing staged or committed. Changed files are as listed above; `present.dart` and `present_snapshot_test.dart` are new (untracked).
