G2 is complete. Here is the report.

## Files created / changed (all inside `packages/party_host`)

**Contract (`lib/`)**
- `lib/party_host.dart` — exports the G2 public surface (16 `src/` files); doc points to `testing.dart`.
- `lib/testing.dart` — the test library (`package:party_host/testing.dart`), a barrel over the three `src/testing/` files; never exported from `party_host.dart`.
- `lib/src/host_identity.dart` — `HostIdentity` (real: const, `==`, `hashCode`, `toString`), doc'd with S-a / M12 §2.6.
- `lib/src/host_directories.dart` — `HostDirectories` interface only (`sessions()`, `exports()`), both doc'd with PRD T17/T18.
- `lib/src/advertiser.dart` — `AdvertiseState` (today's 3 values), `AdvertiserStatus` (state, advertisedName, error), `Advertiser` (`start`/`stop`/`status`/`changes`), `BonsoirAdvertiser` declaration (constructor + throwing bodies).
- `lib/src/local_player_source.dart` — `LocalPlayerSource`, `LocalPlayerSourceFactory`, real `NoLocalPlayerSource`, `localPlayerSourceProvider` defaulting to it.
- `lib/src/host_service.dart` — `HostService` interface, renamed from `HostController`, same members incl. `static const maxSims = 3`.
- `lib/src/host_view_state.dart` — `LocalAddress`, `HostViewState` (today's members; `players` body throws).
- `lib/src/host_log_export.dart` — `buildLogExport`, `latencyText` signatures (needed by the copied test); bodies throw.
- `lib/src/saved_pairings.dart` — `loadPairings`, `savePairings` signatures; bodies throw.
- `lib/src/stats_state.dart` — `StatsState` + `_keep` (copyWith body throws).
- `lib/src/stats_service.dart` — `SessionFile` (id body throws), `StatsService` interface.
- `lib/src/session_uploader.dart` — `SessionUploader` interface, `FirestoreUploader` with today's constructor and `project`/`apiKey`; `upload` throws.
- `lib/src/live_stats.dart` — `LiveStats` with today's constructor and public fields/getters (`session`, `directory`, `start`, `endSession`, `dispose`), all bodies throwing.
- `lib/src/sound.dart` — `SoundStatus` (`loaded` throws), `SoundPlayer` interface.
- `lib/src/screen_awake.dart` — `ScreenAwake` interface only.
- `lib/src/providers.dart` — only `hostIdentityProvider` and `hostDirectoriesProvider`, both throwing.
- `lib/src/testing/host_fakes.dart` — `FakeHostService` (was `FakeHostController`), `FakeGameHost`, `FakeStats`, `FakeUploader`, written for real.
- `lib/src/testing/adapter_fakes.dart` — `FakeSoundPlayer` (moved out of the sound file per Q13, declared now), `FakeScreenAwake`, `FakeAdvertiser`, `FakeHostDirectories` (real folders under a base dir, via `package:path`).
- `lib/src/testing/samples.dart` — `sampleState`, `phoneInfo`, `withController`, `sampleSession`.

**Tests (`test/`, copied not moved; `tv_test_app` untouched)**
- `test/host_identity_test.dart` — new: equality and hash for equal values; inequality for each differing field.
- `test/local_player_source_test.dart` — new: `NoLocalPlayerSource` offers no player and ignores keys without joining.
- `test/host_log_export_test.dart`, `test/saved_pairings_test.dart`, `test/game_players_test.dart`, `test/live_stats_test.dart` (5 stats tests), `test/firestore_uploader_test.dart` — copied from `tv_test_app`, imports switched to `package:party_host`.

## Checks

- `tools/check.sh format analyze` → **PASS format, PASS analyze** (`All checks passed`).
- `flutter test` in `packages/party_host` (run only to count compilation, not reported as a check): **all 12 tests compile**. 3 pass (`host_identity` ×2, `local_player_source` ×1); the other 9 fail at run time with `UnimplementedError` from the stubs, as the brief allows.
- No `Platform.isX` and no `path_provider`/`bonsoir`/`wakelock` import in `party_host`; `dart:io` only for `Directory`/`HttpClient`. Largest file `lib/src/testing/host_fakes.dart` at 288 lines; all others under 300 (tests under 500).
- `tv_test_app` has no content changes. `git status` shows `tv_test_app/windows/flutter/generated_plugin_*` as modified, but `git diff` is empty — line-ending/stat churn from the earlier `flutter pub get`, dated 14:18 (setup), not this job.

## Questions / suggestions for Claude

1. **`buildLogExport` signature.** I kept today's `(HostViewState, LogBuffer, {required DateTime now})` so the copied test compiles unchanged. S-a replaces its `Platform.operatingSystem` with `HostIdentity.hostOs`, so G3 likely needs a fourth input (`HostIdentity` or `String hostOs`) — which shape do you want, and that test then changes with it.
2. **`FakeUploader` added to `testing.dart`** (not in Q10's list) because `live_stats_test` needs one; the alternative was a second copy in the test file, which Q10 forbids.
3. **`testing.dart` is a barrel** over `src/testing/{host_fakes,adapter_fakes,samples}.dart`: one file would be ~490 lines, over the 300-line rule. The import path is unchanged and nothing is exported from `party_host.dart`.
4. **Value-class stubs throw**, per "bodies `throw UnimplementedError()`": `LocalAddress.==`/`hashCode`, `HostViewState.players`, `StatsState.copyWith`, `SessionFile.id`, `SoundStatus.loaded`. Consequence: `FakeStats.setConsent` throws until G3, and `game_players_test` fails on `HostViewState.players`. If you'd rather have those tiny value bodies real already, each is a few lines.
5. **`LocalPlayerSourceFactory` can't default to `NoLocalPlayerSource.new`**: the typedef takes a `GameHost`, which a zero-arg constructor isn't assignable to. The provider returns a private `_noLocalPlayer` function instead. If you want a tear-off, the typedef has to drop `GameHost`.
6. **`localPlayerSourceProvider` lives in `local_player_source.dart`** as the brief says; guideline §7 says providers live in provider files. Brief wins — should it move into `providers.dart` at G4?
7. **No `session_recorder.dart` yet**: Q6's split applies to the record translation, which is private and doesn't exist in stubs; G3 creates it.
8. `BonsoirAdvertiser`'s constructor is real and empty (only its method bodies throw), so a test could construct it by mistake; say the word if you want the constructor to throw too.
---- flash usage: 104 turns, 498 s, input 80547 + cache read 6397440 + cache write 0, output 69452 tokens

---- flash: worker exit 0, model deepseek-v4-flash, log /tmp/flash-20261106-142118.log
---- files this run changed (27)
  packages/party_host/lib/party_host.dart
  packages/party_host/lib/src/advertiser.dart
  packages/party_host/lib/src/host_directories.dart
  packages/party_host/lib/src/host_identity.dart
  packages/party_host/lib/src/host_log_export.dart
  packages/party_host/lib/src/host_service.dart
  packages/party_host/lib/src/host_view_state.dart
  packages/party_host/lib/src/live_stats.dart
  packages/party_host/lib/src/local_player_source.dart
  packages/party_host/lib/src/providers.dart
  packages/party_host/lib/src/saved_pairings.dart
  packages/party_host/lib/src/screen_awake.dart
  packages/party_host/lib/src/session_uploader.dart
  packages/party_host/lib/src/sound.dart
  packages/party_host/lib/src/stats_service.dart
  packages/party_host/lib/src/stats_state.dart
  packages/party_host/lib/src/testing/adapter_fakes.dart
  packages/party_host/lib/src/testing/host_fakes.dart
  packages/party_host/lib/src/testing/samples.dart
  packages/party_host/lib/testing.dart
  packages/party_host/test/firestore_uploader_test.dart
  packages/party_host/test/game_players_test.dart
  packages/party_host/test/host_identity_test.dart
  packages/party_host/test/host_log_export_test.dart
  packages/party_host/test/live_stats_test.dart
  packages/party_host/test/local_player_source_test.dart
  packages/party_host/test/saved_pairings_test.dart
 packages/party_host/lib/party_host.dart | 19 +++++++++++++++++++
 1 file changed, 19 insertions(+)
---- tools/check.sh format analyze
PASS  format      (1s)
PASS  analyze     (7s)
All checks passed (9s). Logs: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261106-142942
---- flash: result 0
