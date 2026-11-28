# glow1 g1: the golden slot's target goes into the match snapshot

## Summary

- Tests first: `packages/puzzle_game/test/golden_snapshot_test.dart` (new, 5 tests). On the base code it failed to compile (`golden` not defined on `MatchSnapshot`), as required.
- `MatchSnapshot` gets `final int? golden` (ctor `this.golden`, dartdoc added). `toJson` writes `'gd': ?golden`, `fromJson` reads `j['gd'] as int?`, `lerpTo` takes `t < 0.5 ? golden : next.golden`.
- `Match.snapshot()` passes `golden: golden` (the existing `Match.golden` getter).
- No other test pins a key list or a byte number for the snapshot: the byte checks compare against `PuzzleSnapshot.maxBytes`, so nothing was adjusted.
- `tools/mine.sh` after the change: format OK (3 files), analyze OK (`packages/puzzle_game`, no findings), touched tests OK (`OK 6 tests packages/puzzle_game`).

Test values computed (expectations written in the test file):
- Round-trip: golden `3` → decode gives `3`, re-encode equals the original encoding.
- No golden: no `gd` key in the JSON; decodes to `null`; re-encode equal.
- Frame without `gd` (key removed from a frame that had `golden: 3`): decodes to `null`, `seed` stays `7`.
- Lerp: from golden `2`, to golden `5`: at `t = 0.4` → `2`; at `t = 0.6` → `5`.
- Byte cost: a set golden adds `,"gd":N` to the frame, which is 7 bytes for a one-digit target (the brief's 7-byte ceiling). A frame with no golden is unchanged.

Self-check (review-rules part A):
1. Host setups: the change is in the shared snapshot model; no host UI touched. Covered by the round-trip tests in `golden_snapshot_test.dart`.
2. Kept state: `golden` is a plain snapshot field, present only when a target exists; with none, no `gd` key (test 2).
3. Combination with pause, away, "Get ready", link drop, results, leaving: no logic added to those paths; `golden` is copied as-is. Not exercised by these tests.
4. Stayed inside `allow:` (3 files changed plus the new test file, see below).
5. Nothing stopped.
6. No look or layout touched.

## Files changed

- `packages/puzzle_game/lib/src/snapshot.dart`: `golden` field, constructor param, dartdoc, `toJson` `gd`, `fromJson`, `lerpTo`.
- `packages/puzzle_game/lib/src/match.dart`: `snapshot()` passes `golden: golden`.
- `packages/puzzle_game/test/golden_snapshot_test.dart`: new file, 5 tests (round-trip, no key when unset, old frame decodes null, lerp at 0.4 and 0.6).
- `docs/briefs/m17/glow1/g1-report.md`: this report.

Not changed: `snapshot_eight_players_test.dart` and `present_snapshot_test.dart` (no pinned value broke, so nothing needed adjusting).

## Questions

1. The `lerpTo` dartdoc lists what each field does; it does not yet mention `golden` (nearer frame wins). I left it alone as the brief's scope; say if you want one line added.
2. `present` field's dartdoc in `snapshot.dart` is over 120 columns (existing, not from this change). `dart format` does not wrap comments, so it passed. Left as is.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

feat(glow1): carry the golden slot's target in the match snapshot

MatchSnapshot gets an optional golden target (key gd), so both boards
can glow the same outline. It is written only while a target is set,
so frames without one are unchanged, and older frames decode with null.
lerpTo takes the nearer frame's target, as it does for the present.
Match.snapshot() passes its golden getter through.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- glow1 g1: done: the golden target is in the match snapshot (`gd`, nearer frame in lerp, tests in golden_snapshot_test.dart). Open: the painter and the phone/host outline (later glow1 jobs).

## Delete

- none
