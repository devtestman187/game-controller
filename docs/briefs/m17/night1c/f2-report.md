## Summary

Job f2: `NightSettingsStore.save` is now awaitable, and the badge ring test is a plain test. No change to what the settings hold, no change to the ring drawing.

Files changed:
- `packages/party_host/lib/src/night/night_settings.dart`: `save` returns `Future<void>` and awaits `_prefs.setString`. `NightSettingsNotifier.update` still returns void and wraps the call in `unawaited`. The load path's `remove` is unchanged.
- `packages/party_host/test/night_settings_test.dart`: `_settle` (a `Future.delayed(Duration.zero)` helper) is deleted. The three tests that waited on it now `await pumpEventQueue()` before reading the prefs. The notifier tests read through the notifier, so no direct store call was needed.
- `packages/party_host/test/player_badge_ring_test.dart`: the `badgeNeedsRing` test is `test(...)` with a sync body, no `tester`.

Checks:
- `tools/mine.sh`: OK. 3 files formatted, 1 package analyzed (no findings), 1 package tested, 12 tests run and passing.

Decisions:
- The brief's `await container.read(prefsProvider).reload()` option was not used: `pumpEventQueue()` is the option the brief names as the fallback and it is simpler.
- No test calls `NightSettingsStore.save` directly (the file has none), so no direct-store test was added. This job is tests-first exempt (test-only cleanup plus a return type).

## Self-check (review-rules part A)

1. Host setups: no UI change; the settings store is shared by all hosts. Covered by existing `night_settings_test.dart` tests.
2. Kept state start and end: settings are read in `build` and saved on `update`; unchanged. Test: `a broken saved string loads the defaults and is removed`, `update saves the settings, and a new container reads them back`.
3. Combination with pause, away, Get ready, drops, results, leaving: no change in behaviour. N/A.
4. Folder and allow: only the four allowed files changed.
5. Stop: nothing needed stopping for.
6. Looks: no widget or layout change; the badge ring test body is unchanged apart from its wrapper. N/A.

## Questions

1. The brief said "tests that call the store directly await save". The file has no direct store tests. Should a direct `await NightSettingsStore(prefs).save(...)` test be added in a later job so the awaitable return is exercised on its own?

## Suggestions

- `docs/briefs/templates/COMMON.md` and the worker extract disagree on the test runner: the brief asks for `dart analyze`, the extract asks for `tools/mine.sh`. I ran `tools/mine.sh` (which includes analyze) and did not run `dart analyze` separately.

## Commit message — a draft

Make NightSettingsStore.save awaitable and drop the test settle

Save now returns Future<void> and awaits the prefs write; the notifier
still calls it unawaited, so update stays void. The night settings tests
await pumpEventQueue instead of the Future.delayed settle helper, which
was a timing guess. The badgeNeedsRing test is a plain test with no
tester. No change to the stored settings or the ring drawing.

## Status row

f2 done: NightSettingsStore.save awaitable, settle helper and badge-ring testWidgets cleaned up (mine.sh OK). Open: no direct store test of save.

## Delete

- none
