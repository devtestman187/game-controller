# d2e report: the pickers Shuffle, Playlist and Rotating chooser

## Summary

Changed:
- `packages/party_host/lib/src/night/night_pickers.dart` (new, about 85 lines): `ShufflePicker`, `PlaylistPicker`, `RotatingChooser`. Pure Dart, const classes, no provider, no UI, no new `NightPicker` value, no wiring, no Vote.
- `packages/party_host/test/night_pickers_test.dart` (new): 13 tests, one group per picker.

Decisions (the brief left these open):
- Shuffle after a full pass: draws are never `played.last`; a one-variant pool returns that variant. An empty `played` with a non-empty pool draws from the whole pool.
- Shuffle "unplayed" means not `==` to anything in `played` (`Variant` has value equality).
- Rotating chooser: a `lastChooser` that is null or not in the list gives the first id, so a leaver's id also gives the first id.
- Playlist: `PlaylistPicker` takes `order` as a named `required` parameter (the brief showed `final List<Variant> order`, a named constructor parameter is the usual Dart form for a const class with one field).

Tests-first: exempt, a new type: the test cannot compile on the base. The test file was written before the lib file.

Test expectations, as written (computed by hand from the rules, not from a run):
- Shuffle, pool of 4 with `Random(7)`: 4 draws are distinct and cover the pool; 10 draws after a full pass never equal `played.last`.
- Shuffle, one-variant pool: returns it. Empty pool: null. Same seed: same 8 draws.
- Playlist over 3 variants: rounds 0,1,2 give items 0,1,2; rounds 3,4 give items 0,1. Empty: null.
- Rotating over p1,p2,p3: null→p1, p1→p2, p2→p3, p3→p1. `[p1,p3]` after p1 → p3. Unknown `p2` on `[p1,p3]` → p1. One player → that player. Empty → null.

Checks:
- `tools/mine.sh`: RESULT ok. Output: `OK 26 tests packages/party_host`, `OK 3 tests packages/test_game`, 5 files formatted, 2 packages analyzed, 2 packages tested. Analyzer was quiet (no findings) on the touched packages. The run took a long time in wall-clock (I did not measure it reliably); it exited 0.
- I did not check that the 26 count is only my 13 tests; the output does not break it down.

Self-check (review-rules part A):
1. Host setups: not applicable, pure Dart, no host UI or wiring.
2. Kept state: none; the pickers hold only const fields.
3. Combination with pause, away, Get ready, drop, results, leave: not applicable, nothing wired yet.
4. Files: only the two allowed files plus this report.
5. Stop: none needed.
6. Look: not applicable, no UI.

## Hand-over

- Next job wires the pickers into the night director and adds the `NightPicker` values. That is outside this job.
- Not wired: `PlaylistPicker.order` is a list the caller supplies. The host-set order is not yet stored anywhere.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

party_host: add the Shuffle, Playlist and Rotating chooser pickers

Pure Dart pickers for M17 plan 1.2 (night2a d2e): ShufflePicker draws
without repeats until every pool variant is played, PlaylistPicker
repeats the host order by round, RotatingChooser walks the players
and skips a player who left. No provider, UI or wiring yet; Vote stays
for B8. Tests in night_pickers_test.dart.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2a d2e: Shuffle, Playlist and Rotating chooser pickers done as pure Dart with 13 tests; open: wiring into the director and the Vote picker (B8).

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`. You can't delete files: the script deletes these after you finish.

- none
