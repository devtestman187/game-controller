# night2b f3 — report

## Files changed

- `packages/party_host/lib/src/ui/night_start_screen.dart`
  - `_StartColumn` is now a `ConsumerWidget` and has five parameters. The `isPicked` parameter is gone; `build` reads it with `ref.watch(nightSettingsProvider.select((settings) => settings.picker != NightPicker.host))`.
  - `_NightStartScreenState._length` is no longer `late` with a `ref.read` initialiser. It is a plain field, with a `NightLength.three` placeholder, and a new `initState` sets it from `ref.read(nightSettingsProvider).length` before the first build.
  - The parent still watches `isPicked` for the footer choice, so that branch is unchanged.

No test file was changed. The four test files in the allow list were run unchanged.

## Checks

- `tools/mine.sh`: OK. 1 file formatted (dart format), 1 package analyzed, 1 package tested. Run once after the edits; no fix was needed after it.
- `flutter test` on `night_start_noscroll_test.dart`, `night_start_frame_test.dart`, `night_screens_test.dart` and `night_setup_screen_test.dart` (run from `packages/party_host`): All tests passed, 82 tests.
- `tools/check.sh` was not run, as the brief asked.

## Self-check (R part A)

1. Host setups: the start card is the same widget for every host setup; `night_start_frame_test.dart` and `night_setup_screen_test.dart` cover the pick and the host's own picks (passed).
2. Kept state: `_length` starts from the saved setting in `initState` and is written back by `_pick` and `_openSetup`, as before. `night_start_frame_test.dart` (the header and back arrow) passed.
3. Combinations: a running night still takes its length from `partyNightProvider` in the parent's `build`, unchanged. Covered by `night_screens_test.dart` and `night_start_noscroll_test.dart` (passed).
4. Only the files in the allow list changed.
5. Nothing was stopped on.
6. Layout: no size or look was changed; `night_start_noscroll_test.dart` covers the card's fit (passed).

## Questions

1. The brief asks for `_length` to be "a plain field set in `initState`". A non-`late` field in a `State` needs an initialiser, so I used `NightLength.three` (the same as the `NightSettings` default) as a placeholder that `initState` overwrites before the first build. If you would rather have no placeholder, the other option is a nullable field, which adds `!` or `?` at every read. Tell me which you want.

## Suggestions

- `_pick` and `_openSetup` both repeat the "read the saved length" step. A helper could share it, but that is outside this job.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

party_host: start card takes five parameters and reads its own pick

_StartColumn reads isPicked itself through a select on nightSettingsProvider,
so it becomes a ConsumerWidget and takes five parameters, not six.
_length of the start screen is no longer a late field with a ref.read
initialiser: it is set in initState, the way the coding guidelines ask.
The card looks and behaves as before; the night_start_* tests and
night_setup_screen_test pass unchanged.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

night2b f3: done — `_StartColumn` at five parameters (reads `isPicked` itself), `_length` set in `initState`; night_start_* and night_setup tests pass unchanged. Open: none (one question on the `_length` placeholder).

## Delete

- none
