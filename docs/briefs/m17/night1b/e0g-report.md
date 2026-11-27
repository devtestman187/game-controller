# night1b e0g: the night save fixes

## Summary

Three fixes to the night save, as the brief asks. Only the three allowed files changed.

1. `NightSave.load()` (`night_save.dart`): a saved night with `round == 0` is cleared and reads as null, as `dropIfUnplayed` does (B-032). The doc comment now says so.
2. `PartyNight.build` roster listener (`party_night.dart`): the listener calls `_set(night.remember(players))` instead of assigning `state`, so players the night remembers are saved. The `night != null` check stays.
3. `night_save_test.dart`:
   - (a) "ending the night clears the save" now runs `start` plus `recordRound` first, asserts `party_night_v1` exists, then calls `end()` and checks the key is gone.
   - (b) NEW: a night saved with round 0 is not resumed by a second container, and its key is cleared.
   - (c) NEW: p2 joins after a round and leaves; a second container loading the save still has p2 in `seen` with nickname "Sam".

Test counts: `tools/mine.sh` ran the 8 tests in `night_save_test.dart`: 8 passed, 0 failed.

Two test-side adjustments were needed beyond the brief:
- The existing "garbled, mistyped or unknown save" test saved a round-0 night as its "valid" save. Under fix 1 that night is cleared, so the test failed. Its valid save now has one round recorded (`record(roundResult(points: {'p1': 5}))`). The broken-save mutations are unchanged.
- Test (c) asserts on `resumed.seen` rather than `rows(...)`. `rows` only lists players on the roster or with totals, so p2 (who has no points) does not appear in it.

Fail-on-base: I did not run the base code (no git commands allowed). By reading: on base, `load()` returns the round-0 night, so (b) fails; the listener does not save, so the save made at `recordRound` has no p2 and (c) fails. The runner's check is the proof.

## Decisions

- New tests (b) and (c) sit in the existing `night_save_test.dart`, as the brief's allow-list names it. The worker rules say new tests go in a new file. I followed the brief.
- Fix 2 saves through `_set`, so the save happens on every roster change while a night runs. This is the brief's instruction.

## Hand-over

Files changed:
- `packages/party_host/lib/src/night/night_save.dart`: `load()` clears and returns null for a round-0 night; doc comment updated.
- `packages/party_host/lib/src/night/party_night.dart`: roster listener saves through `_set`.
- `packages/party_host/test/night_save_test.dart`: clear-on-end test asserts the save exists first; garbled-save test uses a played night as its valid save; new tests (b) and (c).
- `docs/briefs/m17/night1b/e0g-report.md`: this report.

Checks: `tools/mine.sh` first run failed (2 tests, both explained above); after the test fixes, `tools/mine.sh` passed: 3 files formatted, 1 package analyzed, 8 tests OK.

## Commit message — a draft

```
night save: drop a night nobody played, save roster changes

A night started but never played (round 0) came back after a restart,
against B-032. load() now clears it, as dropIfUnplayed does.

The roster listener assigned state directly, so the players a night
remembered were not saved. It now saves through _set.

The clear-on-end test now asserts a save exists before end(); two new
tests cover the round-0 save and a player who joins then leaves.
```

## Status row

night1b e0g: done — night save drops a round-0 night on load, saves roster changes, and the clear-on-end test asserts a save exists first; open: the device check of a restart after a roster change.

## Delete

- none
