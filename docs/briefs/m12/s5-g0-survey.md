# M12 step 5 G0 survey — host mode on the phone

Read-only survey; files changed: this report only (`docs/briefs/m12/s5-g0-survey.md`). Facts read from the code unless
marked **unsure** (inferred or not measured).

## Answers

**1. `HostService`** (`packages/party_host/lib/src/host_service.dart:25-68`): state, changes, newPairingCode, maxSims=3, add/stopSimulatedController(s), dropAllConnections, forgetPairings, exportLog, gameHost, stats, gameSounds, dispose — **no start/stop**. `LiveHostService :77` ctor `:82-92` (prefs, log, identity, directories, advertiser, uploader?), host id `:94-99`, `HostServer(listeners:[WebSocketListener])` `:102-115` (no in-process listener), `ServerGameHost :116`, `LiveStats :117-127`, sims `:128-134`. `start() :191-211`: stats `:194-198`, server `:199-206` (failure → `serverError`, returns), 10 s address timer `:147,:209`, advertising `:274-282`; lifecycle is start + `dispose :261-272`, no stop/restart.
Sound is not started here: `gameSounds :243` → `soundPlayerProvider` (`providers.dart:119-123,156-161`), played by `HomeScreen` (`tv_test_app/.../home_screen.dart:30`). TV supplies identity `tv_host_setup.dart:21-31`, `TvDirectories :42-68`, uploader `:72-73`, prefs/log `main.dart:12,18-24`, keyboard player `:23`.

**2. Advertising.** `Advertiser` (`advertiser.dart:40-55`: start({serviceName,port,txt}), stop, status, changes); one implementation `BonsoirAdvertiser :64-130` (start `:81-106`, stop `:108-119`, failure → `AdvertiseState.failed :121-124`) for all platforms. TXT today `id`+`v` (`network.dart:9,12`; `host_service.dart:280`), no `kind`; type `_gamectl._tcp` (`network.dart:6`), port 45780 (`:16`). `bonsoir ^7.1.5` (`party_host/pubspec.yaml:17`, `controller_app/pubspec.yaml:14`; `pubspec.lock:44-58` android+darwin). Discovery `BonsoirHostDiscovery` (`controller_app/lib/src/discovery.dart:70-190`) reads `id`/`v` (`:172-175`); `DiscoveredHost` has no kind (`:8-19`).
iOS: `NSLocalNetworkUsageDescription` (`Info.plist:29-30`), `NSBonjourServices=[_gamectl._tcp]` (`:31-34`), no `UIBackgroundModes`. Android: `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `VIBRATE` (`AndroidManifest.xml:4-8`), no `FOREGROUND_SERVICE`/`WAKE_LOCK`. **Unsure:** bonsoir broadcasting works on iOS/Android (packages present), but nothing here has run it on a phone.

**3. In-process link.** No production caller: only tests build `InProcessListener`/`InProcessConnector` (`connection/test/helpers.dart:20-29,85-95`, `transport_test.dart:178-250`, `fake_host.dart:31-36`); channel tests loop `TestTransport.values` (`pairing_test.dart:11`). Nothing is skipped: `hello` (`client_connection.dart:110`), code/saved token on welcome (`client_messages.dart:113-137`), heartbeats (`:111`, `client_connection.dart:199-213`), close codes. Pairing pinned (`pairing_test.dart:14-25`); `isLocal` reaches the host (`host_connection.dart:178`), pinned with a null address (`pairing_test.dart:27-37`).

**4. Phone navigation.** `main.dart:9-17` (landscape, immersive, prefs, `ProviderScope(prefs)`), `MaterialApp(home: ControllerScreen)` (`:24-31`). `ControllerScreen` reconnects to the last host on the first frame or opens `ConnectScreen` (`controller_screen.dart:39-42`; chip `:327-339`, `openConnect :295`). `ConnectScreen` (`connect_screen.dart:13-49`) = host list (`:73-124`), manual entry (`:160-218`), `ConnectionPanel` (`:221-318`; idle `:234-249`, failed `:276-307`, both with "Try without a TV"), pops once connected (`:18-20`) — C25's "Host a game" belongs there. Client: `clientProvider` (`providers/connection.dart:31-54`, `WebSocketConnector :38`), tokens in `ConnectionStore` (`storage.dart:61-103`). `controller_app/pubspec.yaml` has no `party_host`.

**5. party_host screens.** `GamesScreen` (`games_screen.dart:18`, no args), `ShapeRaceScreen` (`:139`, `puzzleLibraryProvider`), `JoinScreen` (`join_screen.dart:62`; choice+teams+keyboard, local `:95`), `PuzzleScreen` (`puzzle_screen.dart:34`; choice/teams/keyboard/match), `GameScreen` (`game_screen.dart:31`; `gameHostProvider`, `localPlayerSourceProvider`), `Pausable`/`_PauseMenu` (`pause_menu.dart:30,133`), `PuzzleSettingsScreen` (`puzzle_settings_screen.dart:12`), `StatsScreen` (`stats_screen.dart:16`), `ControlsClaim`/`ControllerMenus` (`controller_menus.dart:28,73`).
TV-only: Escape/debug keys (`game_screen.dart:67-80`, `games_screen.dart:25-26`, `join_screen.dart:233`, `puzzle_screen.dart:90`), remote `autofocus` (`host_button.dart:11`), remote-worded hints (`game_screen.dart:99-101,123-124`). Local player opt-in via `localPlayerSourceProvider`, default `NoLocalPlayerSource` (`providers.dart:248-251`). No screen reads `Platform`/window and all are plain `Scaffold`s (touch works); none takes a host `kind`. TV strings: `host_service.dart:192,278`, `host_log_export.dart:18`, `stats_screen.dart:270`.

**6. Consent, stats, best times, settings.** Consent prefs bool `statsConsent` (`live_stats.dart:51,102,145`), uploaded ids `uploadedSessions` (`:103,266`). Sessions: one JSON per session under `HostDirectories.sessions()` (`host_directories.dart:11-18`); TV path app support + `sessions`/`sessions-debug` (`tv_host_setup.dart:49-51`); atomic write (`session_store.dart:32-41`), list `:45-59`, export to `exports()` `:63-80` (Android external folder else Downloads, `tv_host_setup.dart:58-67`). Settings: prefs `puzzleSettings` JSON (`providers.dart:257-280`), `hostId` (`host_service.dart:142`), `pairings` (`saved_pairings.dart:11-26`).
SharedPreferences works unchanged on iOS/Android. **Best times: no store** — `bestTimeS` is in-memory per match (`test_game/lib/src/arena.dart:143,243,390-392`), no prefs key. **Unsure:** whether `TvDirectories` (Downloads/external, TV-shaped) suits a phone; the phone needs its own `HostDirectories`.

**7. `HostType` and battery.** `HostType` (`metrics/lib/src/session.dart:80-85`): `android_tv`, `windows`, `phone`, `other` — `phone` exists, `tablet` does not. Set in `tv_host_setup.dart:24-28`, via `HostIdentity.hostType` (`host_identity.dart:28`) into `LiveStats(hostType:)` (`host_service.dart:122`) and `SessionCollector` (`live_stats.dart:184-191`), written `'host':{'type':…}` (`session.dart:365`), read by the report (`report.dart:36,83,156`). `deviceStatus` → `battery` (0-1 or -1), `charging`, `thermal` (nominal|fair|serious|critical), `cpuMs`, `lowPower` (`device_status.dart:7-62`, channel `com.thumbparty.app/haptics :49`; `AppDelegate.swift:105-119`, `MainActivity.kt:65-86`); `SessionMonitor` samples every 10 s (`:112-165`). Only the phone app implements it; `party_host` has none.

**8. App lifecycle.** Phone: `_ControllerScreenState` is the only `WidgetsBindingObserver` (`controller_screen.dart:34`); resumed → discovery restart, `client.resume()`, gyro resume, haptics unpause (`:56-66`); else gyro pause, haptics paused, release all (`:67-72`). `party_host` and `tv_test_app` have none, so the TV does nothing on pause/resume. Client pieces: `replaceQuietChannel` (`client_connection.dart:140-146`), `resume()` (`controller_client.dart:233-243`).

**9. Sound.** `flutter_soloud ^5.2.1` (`party_host/pubspec.yaml:23`); `SoLoudSoundPlayer` (`sound.dart:53-140`: init `:76`, `loadAsset(findSound(...))` `:85-91`, play `:103-115`, dispose `:126-134`). Assets in `game_assets`: `audio/<event>.ogg` (`assets/lib/asset_manifest.dart:42`), bundle key `packages/game_assets/audio/…` `:46`, resolved via manifest `:51-60`; 10 files in `assets/audio/` (`assets/pubspec.yaml`). **Unsure:** flutter_soloud is cross-platform and the phone floors (minSdk 31 `build.gradle.kts:35`, iOS 26.0 `project.pbxproj:363`) are above it, but the phone has never run it.

**10. No Wi-Fi.** `WebSocketListener._bind` tries anyIPv6, anyIPv4 on `preferredPort` (45780), then any port (`web_socket_listener.dart:46-66`; `network.dart:16`); all failing → `ListenFailed` → `serverError`, `start()` returns (`host_service.dart:199-206`). `HostServer.port` = first listener with one (`host_server.dart:110-117`); a port-less listener only skips a log line (`:136-139`). No interface → empty address list (loopback filtered, `network_addresses.dart:12-19`), refresh errors logged (`host_service.dart:284-295`), a failed advertisement is only `AdvertiseState.failed` and hosting continues (`advertiser.dart:121-124`); the in-process player needs no network (`in_process_link.dart:11-28`). **Unsure:** with Wi-Fi off binding anyIPv4 should still succeed on loopback, so the solo puzzle should start; not tested.

## Sizes

| File | Lines |
| --- | --- |
| `controller_app/pubspec.yaml` / `lib/main.dart` / `lib/src/app_info.dart` | 34 / 33 / 14 |
| `controller_app/lib/src/ui/connect_screen.dart` / `ui/controller_screen.dart` | 412 ⚑ / 456 ⚑ |
| `controller_app/lib/src/providers/connection.dart` / `providers/device.dart` / `storage.dart` | 184 / 79 / 107 |
| `controller_app/ios/Runner/Info.plist` / `android/app/src/main/AndroidManifest.xml` | 84 / 55 |
| new `controller_app/lib/src/host/**` (presence, monitor, directories, identity) | new |
| `controller_app/test/support/pump_app.dart` / `test/connect_screen_test.dart` | 117 / 99 |
| `party_host/lib/src/host_service.dart` / `providers.dart` / `advertiser.dart` | 305 ⚑ / 280 / 130 |
| `party_host/lib/src/ui/join_screen.dart` / `game_screen.dart` / `games_screen.dart` | 297 / 267 / 199 |
| `party_host/lib/src/ui/pause_menu.dart` / `puzzle_screen.dart` / `stats_screen.dart` | 181 / 185 / 294 |
| `party_host/lib/src/ui/controller_menus.dart` / `lib/src/testing/host_fakes.dart` | 261 / 312 ⚑ |
| `connection/lib/src/host_server.dart` / `host_connection.dart` / `controller_client.dart` | 379 ⚑ / 394 ⚑ / 379 ⚑ |
| `connection/lib/src/transport/in_process_listener.dart` | 36 |
| `metrics/lib/src/session.dart` | 424 ‡ |
| `tv_test_app/lib/main.dart` / `lib/src/tv_host_setup.dart` | 50 / 73 |

⚑ over 300, ‡ over the 400 hard limit.

## Constraints

- Exported API: `party_host.dart:8-34` (Advertiser, HostService, HostIdentity, HostDirectories, providers, screens);
  `connection.dart:8-33`. `HostService` is also implemented by `FakeHostService` (`host_fakes.dart:14`), used by the TV
  app's tests (`tv_test_app/test/support/pump_app.dart:46`) and `party_host/test/support/host_harness.dart:34` — any
  interface change touches them.
- Name clashes: both apps define `prefsProvider` (`controller_app/lib/src/providers/device.dart:15`,
  `party_host/lib/src/providers.dart:39`), `logProvider` (`controller_app/lib/src/providers.dart:19`, `party_host :43`)
  and `logLinesProvider` (`:29` / `:142`); a host-mode file importing both needs prefixes.
- Route names: `Pausable`'s Quit pops to `gamesRouteName` `/games` (`pause_menu.dart:14,131`); the TV registers that name
  (`home_screen.dart:219`).
- Persisted keys/formats: `hostId`, `pairings`, `statsConsent`, `uploadedSessions`, `puzzleSettings` (answer 6); session
  files carry `schema` (`session_store.dart:52`); service TXT `id`/`v` (answer 2).
- Wire: `protocolVersion = 1` (`version.dart:6`); this step's only wire change in the design is the TXT `kind`.
- Tests pinning behaviour: transport pair on both channels (`pairing_test.dart:11-37`, `transport_test.dart:178-250`),
  `live_stats_test.dart` (344), `party_host` screen tests, `tv_test_app/test/home_screen_test.dart` (316).
  No test constructs `LiveHostService` today; only `providers.dart:65` does.

## Conflicts

1. §2.1 says the in-process player is reported as `GamePlayer.local`. Today `local` is only the keyboard `LocalPlayer`
   (`server_game_host.dart:135-137`, `game_types.dart:11`); a connected in-process phone is an ordinary player
   (`server_game_host.dart:125-134`) whose channel shows only in `ControllerInfo.isLocal` (`host_types.dart:49-54`,
   `host_connection.dart:178`). Making it `local` would remove it from `ControllerMenus`
   (`controller_menus.dart:144-147`) and record it as a keyboard local with `hostOs` (`live_stats.dart:154-155,164`).
2. §2.6 lists sound under `HostService`; sound is providers (`providers.dart:119-123,156-161`) and the interface has no
   start/stop (`host_service.dart:25-68`).
3. §2.10 wants the server checked/restarted on resume; `HostServer.start/stop` exist (`host_server.dart:121-157`) but
   `LiveHostService` exposes only `start`/`dispose` (`:191,:261`) and starts stats, the address timer and advertising once.
4. §2.9 `kind`: the `txt` map is free-form (`advertiser.dart:45`), so the record needs code only in
   `host_service.dart:280`, but the advertised name and log say "Thumb Party TV" (`:278`, `:192`, `host_log_export.dart:18`,
   `stats_screen.dart:270`).
5. §2.6 says `HostType` "gains `phone` and `tablet`"; `phone` already exists and `tablet` does not (`session.dart:80-85`),
   while `DeviceInfo` kinds include tablet/foldable (`capabilities.dart:45-47`, `storage.dart:36`).
6. C34 "Show on this device" has no setting or code path: the screens always draw the game, and the only "own player"
   switch is `localPlayerSourceProvider` (`providers.dart:248-251`).
7. §2.9 "the iOS Bonjour declaration to cover advertising": `_gamectl._tcp` is already listed (`Info.plist:31-34`);
   nothing in the repo says what else is missing (**unsure**).
8. §2.10 assumes the host phone keeps or restarts its socket; neither manifest/plist asks for background time
   (`android .../AndroidManifest.xml:4-8`, `Info.plist` has no `UIBackgroundModes`).

## Questions

1. Where should the phone's `HostDirectories` point (sessions and exports on iOS, which has no external storage folder)?
2. Should the host phone's own player be `GamePlayer.local` (conflict 1) or stay a normal player, with `isLocal` only on
   `ControllerInfo`?
3. Does the phone advertise as "Thumb Party TV (…)" or with a name without "TV" (conflict 4)?
4. Are best times (C29/S6) part of this step? No store exists today (answer 6).
5. Is `HostType.tablet` required in this step, and how is a tablet detected on iOS (the shell supplies the kind,
   `storage.dart:36`)?
6. What restarts the listening socket after a background: a new `HostService` member or a `HostPresence` that owns the
   server (conflict 3)?
7. Has bonsoir's broadcast been proven on iOS/Android phones anywhere (answer 2)?
