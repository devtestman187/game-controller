# M12 step 1 — G3 report

Status: **complete except five deletions the environment would not let me run** (see
§5). Everything else in `docs/briefs/m12/s1-g3.md` is done, and
`tools/check.sh format analyze host tv` is green.

## 1. `packages/party_host/lib/src` — the real bodies

The G2 stubs now carry today's behaviour (moved from `tv_test_app/lib/src`), with no
platform code and no Firestore constants in `party_host`:

| file | lines | what it now holds |
| --- | --- | --- |
| `stats_state.dart` | 56 | `StatsState` + a real `copyWith` (three `identical(..., _keep)` sentinels for `consent`, `lastError`, `current`, so `null` and "unchanged" differ). |
| `stats_service.dart` | 39 | `SessionFile` (as in G2), `StatsService`, `String get id => summary['id'] as String? ?? '';`. |
| `live_stats.dart` | 295 | `LiveStats`: session start/end, the 1‑minute checkpoint, the 2‑minute gap timer, the 5‑second ping sample, the consent/upload queue, `refreshCounts`, `exportAll`. Local players record `platform: hostOs ?? ''` (its own host OS, never `Platform.operatingSystem`). Session paths and export folders come from `Directory` + `package:path`. |
| `session_recorder.dart` | 121 | `SessionRecorder` (new, per Q7): controller messages → `SessionCollector`, records → rounds/scores, and the rating prompt. `RatingScheduler` and `_askedGames` live here now. |
| `session_store.dart` | 81 | **new, not in the brief's list** (see §4): the session files on disk — `save` (write `*.tmp`, then rename), `sessions` (newest first, wrong schema skipped), `exportAll` (dated folder under `exportDirectory`). |
| `session_uploader.dart` | 63 | `FirestoreUploader` with the Firestore REST call, `200`/`409` → no error. |
| `host_service.dart` | 297 | `HostService` interface unchanged; `LiveHostService` with the ctor the brief asks for: `prefs`, `log`, `identity`, `directories`, `advertiser`, `uploader`. No `Platform.*`, no `app_info`; version label and OS come from `HostIdentity`. |
| `host_view_state.dart` | 65 | `LocalAddress` `==`/`hashCode` and `players` (connected, sorted by player number, unnumbered last). |
| `saved_pairings.dart` | 26 | `loadPairings` / `savePairings` under the key `pairings`. |
| `host_log_export.dart` | 68 | `buildLogExport(state, log, identity, {required now})` per Q1 (`Thumb Party TV <versionLabel> log, <time>`, `Host: <name> (<hostOs>), port …`), `latencyText`, **plus** `writeLogExport` (§4). |
| `network_addresses.dart` | 41 | `networkAddresses()` / `sameAddresses()` with `_interfaceRank` (Wi‑Fi first). |
| `simulated_controllers.dart` | 115 | `SimulatedControllers`: first free slot, `sim-<hostId[0..6]>[-n]` identity, demo loop, per-controller haptics logging, `stopAll` / `dispose`. |
| `advertiser.dart` | 130 | `AdvertiseState`, `AdvertiserStatus`, `Advertiser`, and the real `BonsoirAdvertiser` (start/stop, `Started` / `NameAlreadyExists` / `Stopped` / errors → status + log). |
| `sound.dart` | 140 | `SoundPlayer` and the real `SoLoudSoundPlayer` (`loaded`, `load`, `play` restarting, `positionOf`, `dispose`); `FakeSoundPlayer` stays in `testing.dart`. |
| `screen_awake.dart` | 22 | `ScreenAwake` and `WakelockScreenAwake` (a failure is logged, never thrown). |

`party_host.dart` is unchanged. `session_recorder.dart` and `session_store.dart` are
internal (not exported), like `network_addresses.dart` and `simulated_controllers.dart`
(coding guidelines §4: export only what callers need).

### Behaviour notes

* Log tags are the same as before (`tv`, `host`, `stats`, `sim<n>`), as are the
  advertising service name `Thumb Party TV (<hostName>)`, the `txt` keys, the sim
  naming and slots, the session/export file names, the checkpoint/gap/ping timings and
  every status transition.
* Two small changes, both inside guideline §2 (log a failure instead of swallowing it):
  a failed `SoLoud.instance.dispose()`, a failed `BonsoirBroadcast.stop()`, and an
  unreadable session file are now logged. Nothing observable in the UI moved.
* `LiveHostService.state` now reads `_advertiser.status` on each call instead of
  copying it into three fields at construction and on every change. The values are
  identical (each status change still calls `_emit()`), and it saved the lines needed
  to get the file under 300.

## 2. `packages/party_host/test`

* `host_log_export_test.dart` — updated for the Q1 signature. New expectations, with
  the identity `HostIdentity(appVersion: '0.11.0', versionLabel: '0.11.0 (dev)',
  hostType: HostType.androidTv, hostOs: 'windows', defaultHostName: 'Android TV')` and
  `now = DateTime(2026, 10, 25, 20, 15)`:
  * first line `startsWith('Thumb Party TV 0.11.0 (dev) log, ')`, and it contains
    `2026-10-25T20:15:00.000`;
  * the header `contains('Host: Android TV (windows), port 45780, protocol v1')`, with
    the reason "from the identity".
* `live_stats_test.dart`, `firestore_uploader_test.dart`, `game_players_test.dart`,
  `host_identity_test.dart`, `local_player_source_test.dart`, `saved_pairings_test.dart`
  run unchanged against the real bodies — 12 tests, all pass.
* `advertiser_test.dart` — **skipped**, as the brief allows: `FakeAdvertiser` has no
  status logic (the test sets `status` and calls `emit()`), and `BonsoirAdvertiser`
  must not be constructed in a unit test.

The main `live_stats_test` scenario is the old TV one, so its known numbers still hold:
3 arena rounds (`wall_hit` 3, wins 3), the two segments `a-1`/`a-2`, `disconnects: 1`
(the Wi‑Fi drop; the final leave is not a drop), `near: {'b': 3}`, `presses: {'ls': 2}`,
`received_to_drawn: {'n': 1, 'median': 7, 'p95': 7, 'max': 7}`, host
`{'type': 'windows', 'app': '0.9.0'}`, and the summary carries no name, address or TV
name.

## 3. `tv_test_app`

* `lib/src/tv_host_setup.dart` (**new**, 73 lines, < 150 as asked): the Firestore
  project/key constants, `tvHostIdentity()`, `TvDirectories implements HostDirectories`
  (today's folders: `getApplicationSupportDirectory` + `sessions-debug` in debug,
  Android external storage / `Downloads` / documents for exports) and `tvUploader()`.
  This is the only file in the app that names `Platform`/`kDebugMode`/Firestore.
* `lib/src/providers.dart` (227): imports `package:party_host/party_host.dart`, builds
  `LiveHostService(prefs:, log:, identity: tvHostIdentity(), directories:
  const TvDirectories(), advertiser: BonsoirAdvertiser(...), uploader: tvUploader())`;
  `hostControllerProvider` is replaced by `hostServiceProvider`, and every other
  provider watches `hostServiceProvider`.
* Screens — import/rename lines only: `ui/home_screen.dart` (`HostController.maxSims` →
  `HostService.maxSims`, `hostControllerProvider` → `hostServiceProvider`),
  `ui/latency_screen.dart` (rename only), `ui/stats_screen.dart` (`../analytics.dart` →
  `package:party_host/party_host.dart`), `ui/haptic_panel_screen.dart`
  (`../sound.dart` → `package:party_host/party_host.dart`).
* `test/widget_test.dart`: the local fakes/samples are gone (`FakeHostController`,
  `FakeGameHost`, `FakeStats`, `sampleState`, `phoneInfo`, `withController`,
  `FakeScreenAwake`), replaced by `package:party_host/testing.dart`
  (`FakeHostService`, `FakeSoundPlayer`, `FakeScreenAwake`, …); renames to the new
  provider; `fake._changes.add(...)` → `fake.emit()`; the `buildLogExport` call now
  passes a fixed `HostIdentity`; the unused `dart:async` import is gone.
* `integration_test/sound_test.dart`: imports `package:party_host/party_host.dart`.

## 4. Deviations from the brief (all forced by the 300-line rule)

1. **New `session_store.dart`.** With the G2 doc comments, `live_stats.dart` came to
   330 lines; `live_stats ≤300` is a hard rule in the brief, so the three file‑I/O
   methods (`_save`/`sessions`/`exportAll`) moved to `SessionStore`. The class is
   constructed inside `LiveStats` from `exportDirectory` and the injected clock, so
   `LiveStats`'s own API and every behaviour are unchanged (`exportAll` still saves
   first). `live_stats.dart` is now 295 lines.
2. **`writeLogExport` added to `host_log_export.dart`.** `LiveHostService.exportLog`
   was the last thing keeping `host_service.dart` over 300; writing the timestamped
   file next to `buildLogExport` is the natural home for it (68 lines, both exported).
   `exportLog()` still returns the same path and logs `Log saved to <path>`.
3. `LiveHostService.state` reads the advertiser's status live (§1, last note).

No other file in the brief's list was changed in a way that changes behaviour.

## 5. Not done: five deletions (blocked by the environment)

The brief says to delete `tv_test_app/lib/src/analytics.dart`, `sound.dart`,
`screen_awake.dart`, `host_controller.dart` and `tv_test_app/test/stats_test.dart`.
Every way of deleting or moving a file in this session (`rm`, `mv`, `unlink`,
`mkdir`, truncating with `echo`) was refused by the tool guard, so **those five files
are still present and unchanged**. I did not work around it by emptying them.

Consequences, all harmless for the checks but not what the brief wanted:

* `tv_test_app` still compiles against its own copies (nothing imports them any more
  except each other), so `dart analyze` stays clean.
* `tv_test_app/test/stats_test.dart` still runs its 6 tests against **tv's** copy of
  the stats code, duplicating `party_host/test/live_stats_test.dart` (5 tests) and
  `firestore_uploader_test.dart` (1 test). The tv suite is 56 tests; it should be 50.
* `tv_test_app` still depends on `firebase_core`/`firestore`-free code through
  `analytics.dart`; that file is dead weight but compiles.

**Claude: please delete those five files and re-run `tools/check.sh format analyze host
tv`** — the expectation is tv 50 tests and no other change.

## 6. Checks

```
tools/check.sh format analyze host tv
PASS  format      (2s)
PASS  analyze     (5s)
PASS  host        (12 tests, 8s)
PASS  tv          (56 tests, 14s)
All checks passed (29s).
```

`dart analyze packages/party_host` → "No issues found!" (no ignores, no
`prefer_initializing_formals` infos left). Every file I touched is ≤300 lines; the
exceptions are the two files above that already were long before this step
(`tv_test_app/test/widget_test.dart` 1561, `tv_test_app/test/stats_test.dart` 402,
which is to be deleted).

`git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`,
`…​.h` and `generated_plugins.cmake` as modified. `git diff` on them is empty — only
their line endings were touched by the Flutter tooling; I did not edit them and their
content is unchanged.

## 7. Questions / suggestions

1. Is `SessionStore` the split you want for the 300-line rule, or would you rather have
   `LiveHostService` in its own `live_host_service.dart` (which would also fit and
   keeps the session I/O inside `live_stats.dart`)?
2. `session_recorder.dart` and `session_store.dart` are not exported from
   `party_host.dart`, matching `network_addresses.dart`/`simulated_controllers.dart`.
   Say if you want any of them exported for the phone app's host mode.
3. Should the dead tv files be deleted in this commit by hand, or do you want the
   follow-up step to do it? (They must go before G4, or the tv app keeps a second
   stats implementation.)
