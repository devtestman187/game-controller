## Summary

- Added `NightSettings` (length, pool, difficulty range, chaos, cat, timer scale, picker), `NightPicker`, `NightSettingsStore` and `nightSettingsProvider` (with `NightSettingsNotifier`: `update`, `useKids`) in `packages/party_host/lib/src/night/night_settings.dart` (about 230 lines). Saved under `party_night_settings_v1` as JSON.
- Added `packages/party_host/test/night_settings_test.dart`: 8 tests, all passing.
- Nothing else changed: no screen, no director or picker logic, no change to `party_night_v1`, no wiring into the start card.
- Tests-first: exempt, a new type; the test cannot compile on the base.
- Decisions:
  1. `chaos` default is `Chaos.off`, read from `PuzzleSettings`' constructor default. The host's own saved default (`hostPuzzleDefaults`) is `Chaos.little`; see Questions.
  2. The Level order check (`difficultyMin` not above `difficultyMax`) is not a constructor `assert`: a const constructor cannot read `Level.index`, and `static const kids` needs that constructor. It is an `assert` in `copyWith`, and `tryFromJson` returns null for it.
  3. The timer range `assert` is in the constructor (plain double comparisons are allowed in const).
  4. `NightSettings.kids` leaves out `length` and `difficultyMin` (they equal the defaults, and the analyzer flags redundant arguments). The test pins all eight values.
  5. `tryFromJson` requires every key; a missing key gives null. `NaN` timer scale gives null (the range check is written so NaN fails it).
  6. Store load of broken JSON catches `FormatException` only (decode boundary), and removes the key.
- Checks run: `tools/mine.sh` (format, analyze, tests): 1st run had analyzer errors (const `index`), fixed; 2nd run had 2 infos (redundant args), fixed; 3rd run green: `OK 8 tests packages/party_host`, `RESULT: ok`.

## Hand-over

- Files: `packages/party_host/lib/src/night/night_settings.dart` (new), `packages/party_host/test/night_settings_test.dart` (new), this report (new).
- Tests named for the self-check (review-rules part A):
  1. Host setups: no UI in this job; the settings are read by no screen yet. N/A until the setup screen job.
  2. Kept state: `load` gives defaults when nothing is saved (`defaults: three rounds...`), and a broken value is removed (`a broken saved string loads the defaults and is removed`).
  3. Combination with pause, host away, "Get ready", results, leaving: N/A, no runtime wiring in this job.
  4. Only the two allowed files and this report were changed.
  5. No stop needed.
  6. No look; N/A.

## Questions

1. Chaos default: the brief says "the same as PuzzleSettings' chaos default", which is `Chaos.off`. The host's own default (`hostPuzzleDefaults` in `puzzle_settings_provider.dart`) is `Chaos.little`. I used `off`. Should `NightSettings` default to `little` to match a new host?
2. The Level order check is in `copyWith` (assert) and `tryFromJson` (null), not in the constructor, because a const constructor cannot compare `Level.index`. Is that acceptable, or should the constructor take a different check?

## Suggestions

- The Kids preset could be an explicit `NightLength.three` and `Level.easy` for readers, if the analyzer's redundant-argument lint is turned off for that line. I left them out to keep the analyzer clean.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night1c n1h: saved night settings and the Kids preset

Adds NightSettings (length, pool, difficulty range, chaos, cat, timer
scale, picker) with JSON round trip that never throws on bad input,
NightSettingsStore over party_night_settings_v1 (a broken save is
removed and defaults load), and nightSettingsProvider with update and
useKids. NightSettings.kids pins Kids: three rounds, easy only, Chaos
little, calm cat, timers at 1.5. Settings only: no screen, no picker
logic, no change to the saved night.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- n1h: done — NightSettings, NightPicker, NightSettingsStore and nightSettingsProvider (Kids preset, update, useKids) in night_settings.dart with 8 tests. Open: the setup screen, the picker logic and the start-card wiring (later jobs); the Chaos default question (off vs little).

## Delete

- none
