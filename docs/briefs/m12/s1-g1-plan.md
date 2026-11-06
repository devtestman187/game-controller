# M12 step 1 — G1 plan: extract `party_host` from `tv_test_app`

## 0. Facts that change the brief's picture

- **`homeLogVisibleProvider` does not exist** anywhere in the tree (grep over all `.dart`/`.md`). The nearest thing is `logLinesProvider` (the home screen's log panel), which is host-side and moves. So on this branch `tv_test_app/lib/src/providers.dart` moves **in full** and nothing stays behind it.
- `tv_test_app/lib/src/providers.dart` contains *only* host-side providers (prefs, log, host service/state, game host, players, sounds, stats state/service, TV events, screen awake, keep awake, puzzle library, puzzle settings). `controlsClaimsProvider` lives in `ui/controller_menus.dart` (it moves with that file, not with `providers.dart`).
- `latency_screen.dart` (stays) also holds `saveLog(context, ref)` and `latencyTargetMs`; `home_screen.dart` uses `saveLog`. So the "stay" keeps a little of the host glue — fine, it uses `hostServiceProvider.exportLog()`.
- `join_screen.dart` / `pause_menu.dart` / `puzzle_screen.dart` import **only** `PlayerBadge` from `latency_screen.dart` (S-d). `PlayerBadge` is a 17-line widget on `playerColor()` from `protocol` → moves as its own file. `latencyText()` is *not* used by screens (only inside `host_controller.dart`).
- `keyboardPlayerAvailable` is a file-level mutable `bool` in `keyboard_player.dart`, flipped by tests. It is the "available" half of S-c.
- `tv_test_app`'s tests are one 1852-line `main()` with shared fakes and a `pumpApp` that mounts the **home screen**; most "move" tests reach their screen *through* `HomeScreen`, which stays. That is the main test-splitting problem (see §3, Q5).

## 1. File-by-file move map

New package root: `packages/party_host`, library file `lib/party_host.dart` that exports what callers need. I propose a **flat `lib/src/`** so every internal relative import (`../providers.dart`, `tv_button.dart`) keeps its shape after the move — the smallest possible diff for a "no behaviour change" step.

### Moves

| Today | New path | Renames | Imports to change |
|---|---|---|---|
| `lib/src/analytics.dart` (524) | split, see §5: `lib/src/stats_state.dart`, `lib/src/stats_service.dart` (StatsService + SessionFile), `lib/src/live_stats.dart`, `lib/src/session_uploader.dart` | — | `dart:io`, `connection`, `metrics`, `protocol`, `shared_preferences` unchanged; **delete `firestoreProject`/`firestoreApiKey`** (S-e) |
| `lib/src/sound.dart` (154) | `lib/src/sound.dart` | — | unchanged (`connection` for `LogSink`, `flutter_soloud`, `game_assets`) |
| `lib/src/screen_awake.dart` (21) | `lib/src/screen_awake.dart` | — | unchanged (`wakelock_plus`) |
| `lib/src/host_controller.dart` (499) | split, see §5: `lib/src/host_service.dart` (HostService + LiveHostService), `host_view_state.dart`, `advertiser.dart`, `saved_pairings.dart`, `host_log_export.dart`, `host_directories.dart`, `simulated_controllers.dart`, `host_identity.dart` | `HostController` → **`HostService`**; `LiveHostController` → **`LiveHostService`** | **drop `app_info.dart`** → `HostIdentity` (S-a); **drop `dart:io` Platform** in `_defaultHostName`, HostType pick, `logExportDirectory`, the two `Platform.operatingSystem` log/export lines (S-a, S-g); `bonsoir` moves into `advertiser.dart` (S-b) |
| `lib/src/providers.dart` (221) | `lib/src/providers.dart` | `hostControllerProvider` → `hostServiceProvider` (proposed, Q2); `HostStateNotifier` etc. keep their names | `analytics.dart` → `live_stats.dart` + `stats_service.dart` + `session_uploader.dart`; `host_controller.dart` → `host_service.dart`; the rest stay `../`-style |
| `lib/src/ui/controller_menus.dart` (274) | `lib/src/ui/controller_menus.dart` | — | `../providers.dart` unchanged; `connection`/`protocol` unchanged |
| `lib/src/ui/games_screen.dart` (199) | `lib/src/ui/games_screen.dart` | — (keeps `gamesRouteName`, S-f) | `tv_button.dart` → `host_button.dart`; siblings unchanged |
| `lib/src/ui/game_screen.dart` (252) | `lib/src/ui/game_screen.dart` | — | **`../keyboard_player.dart` → `LocalPlayerSource` (S-c)**; `../providers.dart`, `controller_menus.dart`, `pause_menu.dart`, `test_game`, `game_assets` unchanged |
| `lib/src/ui/join_screen.dart` (366) | `lib/src/ui/join_screen.dart` | — | **`../keyboard_player.dart` → `LocalPlayerSource` (S-c)**; **`latency_screen.dart show PlayerBadge` → `player_badge.dart` (S-d)**; `tv_button.dart` → `host_button.dart` |
| `lib/src/ui/pause_menu.dart` (180) | `lib/src/ui/pause_menu.dart` | — | `latency_screen.dart show PlayerBadge` → `player_badge.dart` (S-d); `tv_button.dart` → `host_button.dart`; `games_screen.dart` for `gamesRouteName` unchanged |
| `lib/src/ui/puzzle_screen.dart` (294) | `lib/src/ui/puzzle_screen.dart` | — | `../keyboard_player.dart` → `LocalPlayerSource` (S-c); `latency_screen.dart` → `player_badge.dart`; `tv_button.dart` → `host_button.dart` |
| `lib/src/ui/puzzle_settings_screen.dart` (161) | `lib/src/ui/puzzle_settings_screen.dart` | — | `tv_button.dart` → `host_button.dart` |
| `lib/src/ui/stats_screen.dart` (373) | `lib/src/ui/stats_screen.dart` | — | `../analytics.dart` → `../stats_service.dart`; `tv_button.dart` → `host_button.dart` |
| `lib/src/ui/tv_button.dart` (65) | `lib/src/ui/host_button.dart` | `TvButton` → **`HostButton`** (file renamed to match) | `flutter/material.dart` only |
| `PlayerBadge` in `ui/latency_screen.dart` (lines 198–216) | **new** `lib/src/ui/player_badge.dart` | — | `flutter/material.dart`, `protocol` (`playerColor`) |
| *(new)* | `lib/src/local_player_source.dart` | — | `flutter/services.dart` (`KeyEvent`), `connection` (`GameHost`) |
| *(new)* | `lib/src/host_identity.dart` | — | `metrics` (`HostType`) |

### Stays (imports that must change)

| File | Change |
|---|---|
| `lib/main.dart` | `src/providers.dart` → `package:party_host/party_host.dart` (`prefsProvider`); `src/ui/controller_menus.dart` → same; add overrides for `hostIdentityProvider` and `localPlayerSourceProvider` (tv adapters) |
| `lib/src/app_info.dart` | none |
| `lib/src/keyboard_player.dart` | add `package:party_host/party_host.dart` and `implements LocalPlayerSource` (S-c); `dart:io`, `connection`, `services` stay |
| `lib/src/ui/home_screen.dart` | delete `../host_controller.dart`, `../providers.dart`, `games_screen.dart`, `stats_screen.dart`, `tv_button.dart`; add one `package:party_host/party_host.dart`; keep `../app_info.dart`, `haptic_panel_screen.dart`, `input_visualizer.dart`, `latency_screen.dart`; `TvButton`→`HostButton`, `HostController.maxSims`→`HostService.maxSims`. `dart:io` stays (its own `Platform.isWindows` hint) |
| `lib/src/ui/haptic_panel_screen.dart` | `../providers.dart` + `../sound.dart` + `tv_button.dart` → `package:party_host/party_host.dart`; `TvButton`→`HostButton` |
| `lib/src/ui/latency_screen.dart` | `../providers.dart` + `tv_button.dart` → party_host; **delete the `PlayerBadge` class**, import it from party_host; `TvButton`→`HostButton` |
| `lib/src/ui/input_visualizer.dart` | none |
| `test/widget_test.dart`, `test/stats_test.dart`, `integration_test/sound_test.dart` | see §3 |

Branding strings (`Thumb Party TV`, the icon, the pairing hint) are *not* in the move list; they stay in `home_screen.dart` and in `LiveHostService`'s log lines via `HostIdentity.versionLabel`/`appVersion` (the literal "Thumb Party TV" in `start()` stays — hard-coded identity of the app, not a device, already there today; note in Q11).

## 2. Moved files that still depend on something outside party_host

Beyond S-c and S-d:

1. **`host_controller.dart` → `app_info.dart`** (`appVersion`, `versionLabel`) — covered by S-a. `HostIdentity` carries `appVersion`, `versionLabel`, `hostType`, `hostOs`, `defaultHostName`. Every use found: ctor (`appVersion`, `HostType` pick, `hostOs`), `start()` log line, `buildLogExport` header.
2. **`host_controller.dart:435` `logExportDirectory()` uses `Platform.isAndroid`** (external storage on Android TV, Downloads on Windows). The brief's rule "no `Platform.isX` outside an adapter" forbids this in party_host. **Seam S-g (needs your decision):** either
   - (a) inject `Future<Directory> Function() exportDirectory` into `HostService` exactly as `LiveStats` already takes it, and the shell owns `logExportDirectory()`; or
   - (b) keep it in party_host behind a `HostDirectories` interface with a fake.
   I recommend (a) — it reuses the existing pattern and is a 2-line ctor change.
3. **`host_controller.dart:192,451` `Platform.operatingSystem`** in the startup log and in `buildLogExport` — replace with `HostIdentity.hostOs` (same value, supplied by the shell). No seam needed.
4. **`analytics.dart:221` `platform: Platform.operatingSystem`** when recording a *local* player — `LiveStats` already has `hostOs`; use it (or a `HostIdentity` field). Slight behaviour note: today it is read from `dart:io`; the shell passes the same value, so identical.
5. **`analytics.dart:252,404,410` and `host_controller.dart:229,427` `Platform.pathSeparator`** — no `Platform.isX`, so the letter of S-a/S-b allows it, but guideline §6 says use `path`. Using `path` is a new dependency the brief did not name → I left it alone and flag it (Q9).
6. **Firestore constants** `firestoreProject` / `firestoreApiKey` (`analytics.dart:14,18`, used in `host_controller.dart:145`) — S-e. They only feed `uploader:`. Proposed seam: a small `StatsConfig { project, apiKey }` value object passed into `HostService` (or into `HostIdentity`); the shell keeps the two `String.fromEnvironment` constants. `HostService` builds `FirestoreUploader` when `project.isNotEmpty` — identical behaviour, `uploader` still injectable for tests.
7. **`sound.dart` → `game_assets`** (`SoundKey`, `findSound`) — a workspace package, allowed by the layer list (assets sits at the bottom). No seam.
8. **Platform plugins inside moved files** that need no seam but are worth knowing: `flutter_soloud` (`sound.dart`), `wakelock_plus` (`screen_awake.dart`), `path_provider` + `kDebugMode` (`sessionDirectory()`, `analytics` paths), `bonsoir` (moves into `advertiser.dart`). All are behind interfaces already (`SoundPlayer`, `ScreenAwake`, `Advertiser`); `sessionDirectory` and the path_provider calls are not — they are app-directory policy. Not required by the brief; flagged as Q7.

Nothing else: I traced every relative import of every moved file, and the only stay-side symbols they touch are `keyboard_player.dart` (S-c), `PlayerBadge` from `latency_screen.dart` (S-d), and `app_info.dart` (S-a).

### Proposed interface shapes (for your G2 contract, not decided here)

```dart
// host_identity.dart
final class HostIdentity {          // S-a
  const HostIdentity({required this.appVersion, required this.versionLabel,
    required this.hostType, required this.hostOs, required this.defaultHostName});
  final String appVersion; final String versionLabel;
  final HostType hostType; final String hostOs; final String defaultHostName;
}

// advertiser.dart                    S-b
enum AdvertiseState { starting, advertising, failed }
abstract interface class Advertiser {
  Future<void> start({required String serviceName, required int port, required Map<String, String> txt});
  Future<void> stop();
  Stream<AdvertiseState> get state;      // + advertisedName / error for HostViewState
}
class BonsoirAdvertiser implements Advertiser { … }   // platform adapter, fake in tests

// local_player_source.dart           S-c
abstract interface class LocalPlayerSource {
  bool get available;                    // was keyboardPlayerAvailable
  bool get hasPlayer;                    // was keyboard.player == null
  bool handle(KeyEvent event);
  void dispose();
}
typedef LocalPlayerSourceFactory = LocalPlayerSource Function(GameHost host, {void Function()? onJoined});
final localPlayerSourceProvider = Provider<LocalPlayerSourceFactory>((ref) => NoLocalPlayerSource.new);
```

`HostService` provider needs its inputs injected like `prefsProvider` is today: `hostIdentityProvider` (throwing, app-overridden) and `localPlayerSourceProvider`. `Advertiser` can default to `BonsoirAdvertiser` inside the provider (tests override `hostServiceProvider` anyway) or be its own overridable provider (Q4).

## 3. Test map

`widget_test.dart` has one `main()` + helpers; `stats_test.dart` is 6 tests. Destination per group/test:

| Source (line) | Test | Package | Proposed file |
|---|---|---|---|
| 376 | pairing code, address, controllers with ping | tv | `test/home_screen_test.dart` |
| 401 | remote reaches and presses every button | tv (opens the 4 screens; `TvButton`→`HostButton`) | `test/home_screen_test.dart` |
| 477, 494, 526, 565, 571, 577 | host state updates, gyro text, stick text, small laptop, 1080p TV, sounds loaded | tv | `test/home_screen_test.dart` |
| 585–662 group `haptic test panel` (4) | — | tv (`haptic_panel_screen` stays) | `test/haptic_panel_test.dart` |
| 664–727 group `test game` (4) | Arena drives, debug overlay, Escape, small window | party_host | `test/game_screen_test.dart` |
| 747 | players in player order + colour (`feedsOf`) | party_host | `test/game_players_test.dart` |
| 754 | each controller drives its own sprite | **tv** (asserts the home screen's `player-a` badge) | `test/home_screen_test.dart` |
| 780, 793 | keep awake, badge + input delay | tv (home screen) | `test/home_screen_test.dart` |
| 799, 818 | latency screen + fits | tv | `test/latency_screen_test.dart` |
| 825 | exported log header + latency | party_host | `test/host_log_export_test.dart` |
| 844 | pairings saved/loaded/broken | party_host | `test/saved_pairings_test.dart` |
| 923, 934 | first-launch consent, prompt once | tv (home screen's `_FirstLaunchConsent`) | `test/home_screen_test.dart` |
| 939, 956, 975 | Stats screen content, Export/Sharing, empty+small | party_host (`StatsScreen` mounted directly; no home needed) | `test/stats_screen_test.dart` |
| 983 | Windows arrows add a keyboard player | tv (KeyboardPlayer override) | `test/keyboard_player_test.dart` |
| 1009 | arena reports rounds/events | party_host | `test/game_screen_test.dart` |
| 1019 | latency stages | tv | `test/latency_screen_test.dart` |
| 1047 | game picker + Shape Race levels | party_host | `test/games_screen_test.dart` |
| 1066 | join → puzzle layouts/status, leaving returns menus | party_host | `test/join_screen_test.dart` |
| 1110 | finished puzzle shows time; Play again | party_host | `test/puzzle_screen_test.dart` |
| 1146, 1221, 1281 | results menu: left/right/A/B, stick keeps focus, B goes back | party_host | `test/puzzle_results_test.dart` |
| 1313 | time-up shows pieces placed | party_host | `test/puzzle_screen_test.dart` |
| 1345 | puzzle settings change/save/reset | party_host | `test/puzzle_settings_screen_test.dart` |
| 1410 | phone works the menus (picker → Shape Race → settings → home) | party_host (needs a stub "home" route; asserts `HomeScreen`) | `test/controller_menus_test.dart` |
| 1468 | held direction repeats, focus stays pressable | party_host | `test/controller_menus_test.dart` |
| 1514 | simulated controllers never work the menus | party_host | `test/controller_menus_test.dart` |
| 1540 | join: fewer-side, switch, leave, max two | party_host | `test/join_screen_test.dart` |
| 1586 | Start begins with teams; sims join themselves | party_host | `test/join_screen_test.dart` |
| 1617 | pause for everyone, who resumes, Quit | party_host | `test/pause_menu_test.dart` |
| 1695 | Arena pauses with Start | party_host | `test/pause_menu_test.dart` |
| 1714 | race winner, Rematch keeps teams, Change teams | party_host | `test/puzzle_screen_test.dart` |
| 1776 | only a joined player begins; watcher can't pause; grace | party_host | `test/join_screen_test.dart` |
| 1815 | add up to three sims, stop | tv (home screen) | `test/home_screen_test.dart` |
| `stats_test.dart` 112, 258, 280, 296, 338 | LiveStats: summary, failed upload queue, consent off, old phone, export | party_host | `test/live_stats_test.dart` |
| `stats_test.dart` 355 (+`_Redirect`) | Firestore request shape | party_host | `test/firestore_uploader_test.dart` |

### Proposed files (all under 500 lines)

**party_host/test/**
- `support/fakes.dart` — FakeHostService, FakeGameHost, FakeStats, FakeScreenAwake, `sampleState`, `phoneInfo`, `withController`, `sampleSession`, `testPuzzles` (~330)
- `support/host_harness.dart` — `pumpHost()` (ProviderScope + MaterialApp + `ControllerMenus`, direct screen mount) (~100)
- `host_log_export_test.dart` (~40), `saved_pairings_test.dart` (~25), `game_players_test.dart` (~20)
- `game_screen_test.dart` (~130), `games_screen_test.dart` (~30)
- `join_screen_test.dart` (~230), `pause_menu_test.dart` (~150)
- `puzzle_screen_test.dart` (~190), `puzzle_results_test.dart` (~220), `puzzle_settings_screen_test.dart` (~60)
- `controller_menus_test.dart` (~250)
- `stats_screen_test.dart` (~100)
- `live_stats_test.dart` (~330), `firestore_uploader_test.dart` (~70)

**tv_test_app/test/**
- `support/fakes.dart` + `support/pump_app.dart` (~330; `pumpApp` with the two extra overrides `hostIdentityProvider`, `localPlayerSourceProvider`)
- `home_screen_test.dart` (~430: 376, 401, 477, 494, 526, 565, 571, 577, 754, 780, 793, 923, 934, 1815)
- `haptic_panel_test.dart` (~90), `latency_screen_test.dart` (~90), `keyboard_player_test.dart` (~40)

`puzzleLibraryProvider.overrideWith(testPuzzles)` moves with the harness; the relative path becomes `../../puzzle_game/puzzles` in party_host.

## 4. `packages/party_host/pubspec.yaml`, workspace and `check.sh`

```yaml
name: party_host
description: >-
  The host side of Thumb Party (PRD v2 M12): the host service, advertising,
  sound, analytics and the host screens. Used by the TV app today and by the
  phone app's host mode later.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.13.0
  flutter: '>=3.38.0'

resolution: workspace

dependencies:
  bonsoir: ^7.1.5
  connection:
    path: ../connection
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.4.3
  flutter_soloud: ^5.2.1
  game_assets:
    path: ../../assets
  metrics:
    path: ../metrics
  path_provider: ^2.1.6
  protocol:
    path: ../protocol
  puzzle_game:
    path: ../puzzle_game
  shared_preferences: ^2.5.6
  test_game:
    path: ../test_game
  wakelock_plus: ^1.8.2

dev_dependencies:
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
```
Plus `packages/party_host/analysis_options.yaml` copied from `packages/puzzle_game/analysis_options.yaml` (exclude `build/**`, `flutter_lints`, `page_width: 120`).

- Root `pubspec.yaml`: add `- packages/party_host` after `- packages/puzzle_game` in `workspace`.
- `tools/check.sh`: add one row `"host|packages/party_host|flutter test|the host service, host screens, sound and stats"` between `puzzle` and `phone`; update the header comment `# Checks: format analyze protocol connection metrics arena puzzle phone tv` → insert `host` after `puzzle` and the `sed -n '2,13p'` help range if it shifts.
- Every version above is copied from `tv_test_app/pubspec.yaml`; nothing new is introduced.
- Follow-up (not this file): `docs/dev-tools.md` check table and `docs/architecture.md`'s dependency diagram/§1 layer list already name `party_host`; the dev-tools table needs the row (Q10).

## 5. Files over 400 lines after the move

| File | Lines | Split along responsibility |
|---|---|---|
| `host_controller.dart` → | **499** | `host_service.dart`: `HostService` interface + `LiveHostService` (~200) · `host_view_state.dart`: `HostViewState`, `LocalAddress` (~55) · `advertiser.dart`: `AdvertiseState`, `Advertiser`, `BonsoirAdvertiser` (~110) · `host_log_export.dart`: `buildLogExport`, `latencyText` (~60) · `saved_pairings.dart` (~20) · `host_directories.dart`: `sessionDirectory` (+ export dir, S-g) (~25) · `simulated_controllers.dart`: `_Sim` + start/stop (~70) · network-address refresh helper goes with `host_view_state.dart` or its own `network_addresses.dart` (~50) · `host_identity.dart` (~35) |
| `analytics.dart` → | **524** | `stats_state.dart` (`StatsState`, `_keep`) (~55) · `stats_service.dart` (`StatsService`, `SessionFile`) (~30) · `live_stats.dart` (~360) · `session_uploader.dart` (`SessionUploader`, `FirestoreUploader`) (~55). `LiveStats` is then under 400 but above the ~300 target; optional second cut: `session_recorder.dart` for `_onMessage`/`_onRecord`/`_maybeAskRatings` (~110), leaving `live_stats.dart` ~250 (Q6) |
| `join_screen.dart` | 366 | below the hard limit; suggested (not required) cut of `_SidePanel` + `_choiceName` into `join_side_panel.dart` to get near 300 |
| `stats_screen.dart` | 373 | below 400; `SessionView` + `askConsent` could become `session_view.dart` / `consent_dialog.dart` |
| `home_screen.dart` (stays) | **635 now** | already over 400 today; the move doesn't create it, but it is the worst offender and will grow by one import. Proposed later split: `_Header`/`buttons`, `_PairingPanel`, `_ControllersPanel`+`_ControllerTile`, `_LogPanel`, `_FirstLaunchConsent` (Q8) |
| `widget_test.dart` | 1852 | split per §3 |

`controller_menus.dart` (274), `puzzle_screen.dart` (294), `providers.dart` (221), `sound.dart` (154) are fine.

## 6. Order of work, as gates

**G2 — package skeleton, contract, moved tests compiling against stubs**
1. Root `pubspec.yaml` + `tools/check.sh` + `packages/party_host/{pubspec.yaml, analysis_options.yaml, lib/party_host.dart}`.
2. Public types with doc comments and stub bodies: `HostIdentity`, `Advertiser`/`AdvertiseState`/`BonsoirAdvertiser` (skeleton), `LocalPlayerSource` + no-op default + `localPlayerSourceProvider`, `StatsConfig`, `HostService` (renamed interface), `HostViewState`/`LocalAddress`, `StatsState`/`SessionFile`/`StatsService`/`SessionUploader`, `SoundStatus`/`SoundPlayer`/`FakeSoundPlayer`, `ScreenAwake`; exports in `party_host.dart`.
3. `party_host/test/support/` fakes + harness, and the move of the tests whose subject is a pure interface/helper (`host_log_export`, `saved_pairings`, `game_players`, the `stats_test` split).
   Expected: `format` + `analyze` green, `host` red (stubs), `tv` still green. `tv_test_app` is untouched except `main.dart`'s ProviderScope when needed.

**G3 — analytics, sound, HostService and their tests**
- Move `analytics` (4 files), `sound`, `screen_awake`, `host_controller` (8 files) with the S-a/S-b/S-e cuts and the S-g choice; `advertiser.dart` gets the real Bonsoir code.
- `tv_test_app`: `providers.dart` now constructs `LiveHostService` with a `hostIdentityProvider` (and `StatsConfig`) local to tv; `hostControllerProvider` → `hostServiceProvider`; delete the four moved source files.
- Move `live_stats_test`, `firestore_uploader_test`; switch `integration_test/sound_test.dart` to `package:party_host/party_host.dart`.
- Expected: `host`, `tv`, `format`, `analyze` green.

**G4 — screens, providers, `tv_test_app` as a shell**
- Move `providers.dart`, all nine UI files, `tv_button.dart` → `host_button.dart` (`HostButton`), add `player_badge.dart`, export `gamesRouteName`.
- `tv_test_app`: `main.dart` overrides (`hostIdentityProvider`, `localPlayerSourceProvider` = `KeyboardPlayer`), `keyboard_player.dart implements LocalPlayerSource`, the four staying screens re-pointed to party_host, deletes the moved copies; finish the test splits of §3.
- `tv_test_app/pubspec.yaml`: add `party_host`; drop `bonsoir`, `path_provider`, `flutter_soloud`, `wakelock_plus` (only the moved files used them) — Q11.
- Expected: `tools/check.sh` fully green; the Windows build runs (step exit check, not run here).

## 7. Questions and suggestions for Claude

1. `homeLogVisibleProvider` does not exist. Did the brief mean `logLinesProvider`, or is it planned for a later step? As written, `providers.dart` moves in full.
2. Confirm the renames I assume: provider `hostControllerProvider`→`hostServiceProvider`, test fake `FakeHostController`→`FakeHostService`, file `tv_button.dart`→`host_button.dart` with class `HostButton`. Also: should `AdvertiseState` keep its name (it reads as a status, not an advertise state)?
3. `HostIdentity` ownership: I propose `party_host` declares `hostIdentityProvider` throwing like `prefsProvider`, and the app overrides it (built from `app_info.dart` + `Platform` in tv). Alternative: pass it through `hostServiceProvider` overrides only. Which?
4. Is `HostIdentity` the right home for `StatsConfig` (S-e), or a separate `StatsConfig`? And should `HostService` build the `FirestoreUploader` (today's behaviour) or take a `SessionUploader?` from the shell?
5. S-g: `logExportDirectory()` has `Platform.isAndroid`. I recommend injecting `Future<Directory> Function() exportDirectory` into `HostService` (as `LiveStats` already does). Approve the seam, or prefer a `HostDirectories` interface?
6. `LiveStats` is 360 lines after the split — under the hard limit, above the ~300 target. Split the record translation into `session_recorder.dart` now or leave it? Same for `join_screen` (366) and `stats_screen` (373).
7. Should `sessionDirectory()` (path_provider + `kDebugMode`) also become a seam, or stay in party_host? No `Platform.isX`, but it is app-directory policy.
8. `home_screen.dart` stays at 635 lines and gets one more import. Split it as part of G4 or leave it for a later job?
9. `Platform.pathSeparator` (5 sites) vs guideline §6's "use `path`". Adding `path` is a new dependency not named in the brief — leave as is?
10. Tests: where do the shared fakes live? party_host cannot import tv_test_app, so either (a) each package keeps its own `test/support/fakes.dart` (~330 lines duplicated), or (b) the moved screens' tests mount their screen directly in party_host and tv keeps only the home/haptic/latency/keyboard tests. I recommend (a) plus (b); this also decides three tests that are tv-bound because they assert `HomeScreen` or the home screen's badges (376/401/754/923/934/1815 stay; 1410 needs a stub home route in party_host).
11. `tv_test_app` dependencies: dropping `bonsoir`, `path_provider`, `flutter_soloud`, `wakelock_plus` after G4 (nothing in the shell uses them; the sound integration test now uses party_host). Approve, or keep them for this step?
12. Not in this job's file list but needed for the "every check passes" exit: `.github/workflows/ci.yml` has a per-package job list and needs a `party_host` job (`.github/` is off-limits to me), and `docs/dev-tools.md` needs the `host` row. Who does those?
13. `FakeSoundPlayer` ships in `lib/src/sound.dart` today (a fake in shipped code, against guideline §2 "test hooks in lib"). Keep it in lib so the moved tests and tv tests can use it, or move it to test support in a later job? I kept it in lib.
14. `controlsClaimsProvider` lives in `controller_menus.dart`, not `providers.dart` (guideline §7 says providers live in provider files). Move it into party_host's `providers.dart` during the move, or keep the diff minimal?
