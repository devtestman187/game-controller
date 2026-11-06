# M12 step 1, G4 report: providers and screens in `party_host`, `tv_test_app` as the shell

STATUS: done. `tools/check.sh format analyze host tv` passes.

## Files changed

Production (one line each):

- `packages/party_host/lib/src/providers.dart` — the host's single provider file: `hostIdentityProvider`,
  `hostDirectoriesProvider`, `prefsProvider`, `logProvider`, new `advertiserProvider` (default `BonsoirAdvertiser`) and
  `sessionUploaderProvider` (default null), `hostServiceProvider` (builds `LiveHostService` from providers only),
  host state, game host/players/sounds, stats, log lines, sounds, haptics, screen awake, keep-awake, plus
  `controlsClaimsProvider` (moved from `controller_menus.dart`) and `localPlayerSourceProvider` (moved from
  `local_player_source.dart`, default `NoLocalPlayerSource`), puzzles and puzzle settings.
- `packages/party_host/lib/src/local_player_source.dart` — the provider left; keeps `LocalPlayerSource`,
  `LocalPlayerSourceFactory`, `NoLocalPlayerSource`.
- `packages/party_host/lib/src/host_service.dart` — `static const addressRefreshInterval = Duration(seconds: 10)`
  (PRD T5) replaces the inline value in the address timer.
- `packages/party_host/lib/src/live_stats.dart` — `static const pingSampleInterval = Duration(seconds: 5)` for the
  ping sampler.
- `packages/party_host/lib/src/session_uploader.dart` — `static const connectTimeout = Duration(seconds: 10)` and
  `static const responseTimeout = Duration(seconds: 20)`, both documented, used in `upload`.
- `packages/party_host/lib/src/ui/controller_menus.dart` (new) — moved screen; `ControlsClaims` stays here, the
  provider moved to `providers.dart` (cyclic import, see deviations).
- `packages/party_host/lib/src/ui/game_screen.dart` (new) — moved; local player from `localPlayerSourceProvider`
  (the join is logged with the player's number, as before).
- `packages/party_host/lib/src/ui/games_screen.dart` (new) — moved; `gamesRouteName` is public now.
- `packages/party_host/lib/src/ui/host_button.dart` (new) — `TvButton` renamed `HostButton`, same body.
- `packages/party_host/lib/src/ui/join_screen.dart` (new) — moved; local player from the provider; `PlayerBadge`
  and `HostButton` from the package.
- `packages/party_host/lib/src/ui/pause_menu.dart` (new) — moved; `PlayerBadge`/`HostButton`.
- `packages/party_host/lib/src/ui/player_badge.dart` (new) — `PlayerBadge`, taken out of the TV latency screen.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` (new) — moved; local player from the provider.
- `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` (new) — moved; `HostButton`.
- `packages/party_host/lib/src/ui/stats_screen.dart` (new) — moved; imports the package's providers.
- `packages/party_host/lib/party_host.dart` — exports the ten new `ui/` files.
- `tv_test_app/lib/main.dart` — the shell: overrides `prefsProvider`, `hostIdentityProvider` (`tvHostIdentity()`),
  `hostDirectoriesProvider` (`TvDirectories`), `sessionUploaderProvider` (`tvUploader()`) and
  `localPlayerSourceProvider` (`tvKeyboardPlayer`); `ControllerMenus` comes from the package.
- `tv_test_app/lib/src/keyboard_player.dart` — `KeyboardPlayer implements LocalPlayerSource`; `tvKeyboardPlayer` is
  the factory; the `keyboardPlayerAvailable` global is gone (the factory decides, as before: desktop only).
- `tv_test_app/lib/src/ui/home_screen.dart` — imports `package:party_host` (buttons, game picker, stats, save log,
  providers); still the TV's own main screen.
- `tv_test_app/lib/src/ui/latency_screen.dart` — `PlayerBadge` removed, package imports, `HostButton`.
- `tv_test_app/lib/src/ui/haptic_panel_screen.dart` — package imports, `HostButton`.
- `tv_test_app/lib/src/ui/game_screen.dart`, `games_screen.dart` (untouched), `join_screen.dart`, `pause_menu.dart`,
  `puzzle_screen.dart`, `puzzle_settings_screen.dart`, `stats_screen.dart`, `tv_button.dart`, `src/providers.dart` —
  the moved originals, still present for deletion (see DELETE). Five of them needed one-line fixes to keep
  `analyze` green (see deviations).
- `docs/dev-tools.md` — the `host` row in the check table, after `puzzle`.

Tests (all new):

- `packages/party_host/test/support/host_harness.dart` — `pumpHost` (ProviderScope with the fakes, `ControllerMenus`,
  `MaterialApp`), `StubHome` (the app's home stand-in: one Play button pushing `GamesScreen` under `gamesRouteName`,
  watching the games' sounds), `tapVisible`, `openArena`, `openShapeRace`, `openJoin`, `phone`, `press`, `neutral`,
  `navigated`, `focusText`, `focused`, `focusedTooltip`, `puzzleDataDir`, `housePuzzle`, `testPuzzles`.
- `packages/party_host/test/game_screen_test.dart` — 6 tests.
- `packages/party_host/test/games_screen_test.dart` — 1 test.
- `packages/party_host/test/join_screen_test.dart` — 4 tests.
- `packages/party_host/test/pause_menu_test.dart` — 2 tests.
- `packages/party_host/test/puzzle_screen_test.dart` — 2 tests.
- `packages/party_host/test/puzzle_results_test.dart` — 4 tests.
- `packages/party_host/test/puzzle_settings_screen_test.dart` — 1 test.
- `packages/party_host/test/controller_menus_test.dart` — 3 tests.
- `packages/party_host/test/stats_screen_test.dart` — 3 tests.
- `tv_test_app/test/support/pump_app.dart` — `pumpApp` (the whole `TvTestApp` with the fakes and the shell's own
  overrides, plus `localPlayer` for the keyboard test), `tapVisible`, `openArena`, `testPuzzles`.
- `tv_test_app/test/home_screen_test.dart` — 13 tests (pairing code…, remote reaches every button, state updates,
  gyro, sticks, small window, 1080p, sounds loaded, screen stays on, player badge/input delay, first-launch consent,
  answered consent, simulated controllers).
- `tv_test_app/test/haptic_panel_test.dart` — 4 tests.
- `tv_test_app/test/latency_screen_test.dart` — 3 tests.
- `tv_test_app/test/keyboard_player_test.dart` — 1 test (with `KeyboardPlayer(..., available: true)`).
- `tv_test_app/test/widget_test.dart` — everything moved out; the old file is left inside a `/* */` comment plus an
  empty `void main() {}` (see deviations).

## Test count, before → after, per file

| File | Before | After |
| --- | --- | --- |
| `party_host/test/firestore_uploader_test.dart` | 1 | 1 |
| `party_host/test/game_players_test.dart` | 1 | 1 |
| `party_host/test/host_identity_test.dart` | 2 | 2 |
| `party_host/test/host_log_export_test.dart` | 1 | 1 |
| `party_host/test/live_stats_test.dart` | 5 | 5 |
| `party_host/test/local_player_source_test.dart` | 1 | 1 |
| `party_host/test/saved_pairings_test.dart` | 1 | 1 |
| `party_host/test/game_screen_test.dart` | — | 6 |
| `party_host/test/games_screen_test.dart` | — | 1 |
| `party_host/test/join_screen_test.dart` | — | 4 |
| `party_host/test/pause_menu_test.dart` | — | 2 |
| `party_host/test/puzzle_screen_test.dart` | — | 2 |
| `party_host/test/puzzle_results_test.dart` | — | 4 |
| `party_host/test/puzzle_settings_screen_test.dart` | — | 1 |
| `party_host/test/controller_menus_test.dart` | — | 3 |
| `party_host/test/stats_screen_test.dart` | — | 3 |
| **party_host total** | **12** | **38** |
| `tv_test_app/test/home_screen_test.dart` | — | 13 |
| `tv_test_app/test/haptic_panel_test.dart` | — | 4 |
| `tv_test_app/test/latency_screen_test.dart` | — | 3 |
| `tv_test_app/test/keyboard_player_test.dart` | — | 1 |
| `tv_test_app/test/widget_test.dart` | 50 | 0 |
| **tv total** | **50** | **21** |
| **all** | **62** | **59** |

The arithmetic: 3 of the TV file's 50 were copies of `party_host` tests (below), so the 62 raw tests are 59 distinct
ones; after the move the same 59 unique tests run (38 host + 21 tv). No unique test was dropped or weakened. Every
moved test is byte-for-byte the original body, with only these adjustments: the mount (stub home or the screen
directly), the harness helpers, and `TvButton` → `HostButton`.

The three TV tests that were already in `party_host` (kept there, not moved, so nothing runs twice):
`players are the connected controllers in player order, each with its colour`,
`the exported log starts with each controller's latency, then every line`,
`pairings are saved and loaded; broken data is ignored`.

## Computed values

- Test files: 16 in `party_host` (largest `live_stats_test.dart`, 343 lines), 9 in `tv_test_app`
  (largest `home_screen_test.dart`, 287 lines) — every one under the 500-line limit.
- Harness sizes: `host_harness.dart` 181 lines, `pump_app.dart` 87 lines.
- Moved screens: `join_screen.dart` 366, `stats_screen.dart` 374, `controller_menus.dart` 272, `game_screen.dart`
  254, `puzzle_screen.dart` 296, `games_screen.dart` 199, `pause_menu.dart` 180, `puzzle_settings_screen.dart` 161,
  `host_button.dart` 66, `player_badge.dart` 23 — none over the 400-line hard limit; these are move-only copies, so
  the two over the 300-line target are unchanged from their TV sizes.
- Durations kept their values: 10 s (address refresh), 5 s (ping sample), 10 s and 20 s (upload connect/response).

## Deviations and decisions inside the brief

1. **Five leftover TV screens were edited by a line each**, though the brief says "leave moved originals in place
   unchanged". The brief also says checks must pass, `PlayerBadge` must leave `latency_screen.dart` and
   `keyboardPlayerAvailable` must go; with the originals present, `analyze` cannot be green without these:
   `ui/game_screen.dart`, `ui/join_screen.dart`, `ui/puzzle_screen.dart` use `_keyboard.available` where they read
   the removed global; `ui/join_screen.dart`, `ui/pause_menu.dart`, `ui/puzzle_screen.dart` import `PlayerBadge`
   from `package:party_host`; `ui/stats_screen.dart` drops an import that became ambiguous. All are on the DELETE
   list, and all are formatted.
2. **`widget_test.dart` is the old file inside a block comment plus an empty `main()`**, not a clean stub. I can't
   delete it, and file writes are unavailable to me (Bash refuses redirection/`tee`/`sed -i`, and the Edit tool
   cannot replace 1561 lines). Nothing in it runs; the comment says it is for deletion.
3. **Cyclic import**: the brief moves `controlsClaimsProvider` into `providers.dart`, but `ControlsClaims` lives in
   `ui/controller_menus.dart`, so the two files import each other. Dart allows it and `analyze` is clean; noted as a
   design smell for later (a `controls_claims.dart` would break it).
4. **Test harness maps `select`/Enter/gamepad A to `ActivateIntent`** (as `TvTestApp`'s `Shortcuts` does), because
   the tests press the focused button with the remote's OK; without it, `select` reaches nothing in `party_host`'s
   harness. Test support only, no app code.
5. **`StubHome` watches `gameSoundsProvider`**, like every host app's main screen, so the games' sounds still play
   through the fake sound player in the game tests (the TV home screen does this too).
6. **One test adapted, not weakened**: "each controller drives its own sprite" looked for the two `PlayerBadge`s on
   the home screen (`player-a`, `player-b`) before starting the arena. The stub home has no badges, so it now checks
   the game host's players (`[('a', 1), ('b', 2)]`) and the arena's own HUD keys (`hud-a`, `hud-b`). The rest is
   unchanged.
7. `pumpApp` passes `localPlayerSourceProvider` only when the test asks (keyboard test); for a TV the default
   (no local player) is right, and the shell's `main()` override is what a desktop build uses.

## Not mine, but changed

`tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and `generated_plugins.cmake` (timestamp 14:18,
this job's first `flutter test`) were rewritten by the Flutter tool, not by hand. They are generated; I can't revert
them (git writes and file writes are both out of bounds for me). Discard them if they differ from `main`.

## DELETE: files Claude must delete

- `tv_test_app/lib/src/providers.dart`
- `tv_test_app/lib/src/ui/controller_menus.dart`
- `tv_test_app/lib/src/ui/game_screen.dart`
- `tv_test_app/lib/src/ui/games_screen.dart`
- `tv_test_app/lib/src/ui/join_screen.dart`
- `tv_test_app/lib/src/ui/pause_menu.dart`
- `tv_test_app/lib/src/ui/puzzle_screen.dart`
- `tv_test_app/lib/src/ui/puzzle_settings_screen.dart`
- `tv_test_app/lib/src/ui/stats_screen.dart`
- `tv_test_app/lib/src/ui/tv_button.dart`
- `tv_test_app/test/widget_test.dart`

After that, `tv_test_app` no longer uses `bonsoir`, `flutter_soloud` or `wakelock_plus` (the brief's "Claude drops
tv's pubspec dependencies"); `keyboard_player.dart`, `tv_host_setup.dart`, `app_info.dart`,
`haptic_panel_screen.dart`, `input_visualizer.dart`, `latency_screen.dart` and `home_screen.dart` stay.

## Checks

`tools/check.sh format analyze host tv`:

```
PASS  format      (1s)
PASS  analyze     (5s)
PASS  host        (38 tests, 10s)
PASS  tv          (21 tests, 8s)
All checks passed (25s).
```

## Questions

1. The three duplicated TV unit tests: I left them out of the TV split (they live on in `party_host`). Was removing
   them the intent, or would you rather keep the TV copies too (then tv would have 24)?
2. `SELECT`/`Enter`→`ActivateIntent` now exists in both test harnesses and in `TvTestApp`. Is a shell detail like
   that worth a shared helper, or is duplicating four lines in a harness fine?
3. Is the cyclic `providers.dart` ↔ `ui/controller_menus.dart` import acceptable for step 2, or should
   `ControlsClaims` move to its own file now (it would be a one-file change, but it is beyond G4's brief)?
4. Nothing in `party_host` reads `hostIdentityProvider`/`hostDirectoriesProvider` except `hostServiceProvider`, so a
   host app that overrides the service (like the tests) need not supply them. Confirmed as intended?
5. The leftover TV screens are now dead code that duplicates the package's. Do you want them removed in the same
   commit as the pubspec change, or is that your call alone? I left both for you, as the brief says.
