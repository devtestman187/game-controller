# night1b e0c report: the night is saved after each change and resumes on restart

## Summary

- Key `party_night_v1` (SharedPreferences, a JSON string). Saved after `start`, `recordRound`, `endNow` and `usedMap`; cleared by `end()`, `dropIfUnplayed()`, and on load when the save is corrupt, unknown, or already over.
- What is saved: length (3 or 5), round, the three awards (names), totals, counters, roundsWon, played, lastRoundPoints, seen (number, nickname, character), outcomes (award, winners, value), maps, isEndedEarly.
- A corrupt save (not JSON, not an object, a wrong type, an unknown award name, a bad character, round out of range) is cleared and the night starts fresh. Nothing is logged.
- The repair: the five test files that built a container through `nightContainer()` now use `savingNightContainer()` (in `test/support/fake_prefs.dart`), which overrides `prefsProvider` with a `FakePrefs`.
- Tests: `tools/mine.sh` → 70 tests OK in packages/party_host, analyze clean. I did not run the full host suite (see questions).
- Computed test values (night_save_test.dart): two players, `p1` scores 5 then 1 (total 6), `p2` scores 2 then 4 (total 6); `p1` wins comeback (+3), so `p1` shows 9 and `p2` shows 6 with `isHere` false and a null nickname. Restart test: round 1 with totals `{p1: 5}` after one round of 5.

## Files changed

- `packages/party_host/lib/src/night/night_state.dart`: new `NightState.restored(SavedNight parts)` factory; imports night_save.dart for the typedef (374 lines).
- `packages/party_host/lib/src/night/night_save.dart` (new): `NightSave` (load/save/clear), `nightSaveProvider`, `SavedNight` typedef, `_nightJson` writer and a validating reader (no throws).
- `packages/party_host/lib/src/night/party_night.dart`: `build` loads the save; `_set` saves or clears on every state change; doc updated.
- `packages/party_host/test/night_save_test.dart` (new): 5 tests (round trip, garbage/mistyped/unknown, restart resumes, end clears, over night not resumed).
- `packages/party_host/test/support/fake_prefs.dart`: `savingNightContainer({FakePrefs? prefs})`.
- `packages/party_host/test/party_night_test.dart`, `champion_test.dart`, `night_award_results_test.dart`, `night_robo_test.dart`, `round_results_test.dart`: `nightContainer()` replaced by `savingNightContainer()`; import added.
- `packages/party_host/test/support/host_harness.dart`: not changed.

## Self-check (review-rules part A)

1. Host setups: the save lives in the `PartyNight` provider, shared by every host setup; no per-setup test was added.
2. Start and end: starts at `start`, ends at `end()` or an over night; with no night, `load` returns null (test 1 and 4).
3. Combinations: `remember` (leavers) is not saved until the next change; pause, away and link drops are not tested.
4. Stayed in allow: yes.
5. Stop: `support/night_harness.dart` (`nightContainer`) needed the prefs override but is not in allow; I did not edit it.
6. Looks: no UI change.

## Questions

1. `night_save.dart` is 187 lines; the brief asked for under 120. The reader is the bulk. Splitting it needs a new file outside allow, so I kept it in one file.
2. `nightContainer()` in `support/night_harness.dart` still lacks a prefs override. Suggest adding `prefsProvider.overrideWithValue(FakePrefs())` there and dropping `savingNightContainer`.
3. `NightState.tryRestore` is not a method: the reader is `_readNight` in night_save.dart, to fit night_state.dart under 380 lines.
4. `SavedNight` lives in night_save.dart and night_state.dart imports it, so the two files import each other. It works; say if you prefer the typedef elsewhere.
5. The roster listener (`remember`) changes the night without saving it; the next change saves it.
6. I did not run `tools/check.sh host` (the instructions forbid it); only `tools/mine.sh` ran. I did not run the restart test against the base, so the "fails on base" claim is unverified; the runner will check.

## Hand-over

Run the runner's full checks. Suggest the question 2 change in a later job.

## Commit message — a draft

Save the party night after each change and resume it on restart

The night now writes itself to prefs (key party_night_v1) after start, each
recorded round, an early end and a Bumper Round's map. A save is cleared when
the night ends or is over. A corrupt, mistyped or unknown save is dropped and
the night starts fresh. Only the night is saved, not the game in progress.

## Status row

e0c done: the night is saved after each change and resumes on restart (party_night_v1, NightSave). Open: night_save.dart is 187 lines (brief: under 120); the harness nightContainer has no prefs override; the roster change is not saved until the next change.

## Delete

- none
