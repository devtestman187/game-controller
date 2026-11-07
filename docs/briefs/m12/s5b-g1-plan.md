# M12 step 5b — G1 plan: host mode in the phone app

Job: [s5b-g1.md](s5b-g1.md). Contract: [m12-host-mode.md](../design/m12-host-mode.md) §3, §4 — it wins. Read with it:
[s5-g0-survey.md](s5-g0-survey.md), [s5a.md](s5a.md) (the host side, in flight), [coding-guidelines.md](../../coding-guidelines.md).

Line numbers are today's files. **s5a has not landed** (`git status` shows nothing under `packages/`): `HostService.resume`,
`HostPresence`, `hostAwayProvider`, `HostIdentity.kind`/`serviceName`, `LiveHostService(inProcess:)` and `HostType.tablet` do
not exist yet. This plan is written against those names (the brief says to), and says which slice needs which of them.

## 0. Facts that shape the plan

### 0.1 The phone app, as host mode has to fit into it

- `ControllerScreen` (150) is the app's only screen (`main.dart:30`). `initState`'s post-frame callback
  (`controller_screen.dart:41-48`) reconnects or opens `ConnectScreen` (`:44`, `openConnect` is
  `controller_parts.dart:116-117`), restores the pad mode (`:46`) and starts the session monitor (`:47`).
- `didChangeAppLifecycleState` (`:58-75`): on resume it restarts discovery (`:62`), resumes the client (`:66`), the gyro
  and the haptics; otherwise it pauses the gyro and haptics and releases every button (`:71-73`).
- `build` (`:97-149`): `ref.listen` on `tvHapticsProvider` (`:101`) and `outagesProvider` (`:102`); the client state
  restarts discovery while reconnecting (`:105-109`); **`discoveryStateProvider` is watched at `:111-116`** and
  `discoveryProvider` starts Bonsoir browsing the moment it is first read (`providers/connection.dart:12-17` — it never
  stops except on `ref.onDispose`, so once started it browses for the app's life). `_followTheGame` (`:79-95`) applies the
  game's layout (`:82-90`) and shows the TV's rating prompt (`:92-94`). Then `_TopBar` (`:134`) over `_Controls` (`:139`),
  sized by `minWindowWidth` 540 (`layout.dart:37`) and `minBodyHeight` 250 (`layout.dart:40`).
- `_Controls` (`controller_parts.dart:5-37`) builds `ControlsLayer(opacity: opacity)` **with no child** (`:31`) — and
  `ControlsLayer` already takes one, drawn behind the controls, with a `SizedBox.shrink()` default
  (`controls_layer.dart:14,21,32`). So the "body behind the controls" seam exists; only the plumbing up is missing. The
  opacity comes from `gameShownProvider` (`:23-25`): over a game the controls take the saved opacity, in controller mode
  they stay opaque — and `gameShownProvider`'s doc already says steps 5 and 6 turn it on (`providers/game_feedback.dart:34-46`).
- `_TopBar` (`controller_top_bar.dart:3-136`) is one 129-line `build` (`:7-135`): the connection chip (`:35-48`, `openConnect`
  at `:46`), the `PlayerBadge` (`:30-33`), the status panel or the ping stats (`:50-64`), the mode `SegmentedButton`
  (`:69-107`), the gyro/stick buttons (`:108-119`), Settings and Diagnostics (`:120-131`).
- `ConnectScreen` (412, over the 400 hard limit) holds `ConnectionPanel` (`:220-318`, with "Try without a TV" in the idle
  branch `:241-249` and again when failed `:299-307`) and `_CodeEntry` (`:320-412`); `_HostList` `:73-124`, `_NoHosts`
  `:126-158`, `_ManualEntry` `:160-218`, `StatusChip` `:51-71`.
- The phone's identity comes from `loadIdentity` (`storage.dart:16-42`): name `'iPhone 3F2A'` (`:31`), capabilities
  metrics/rating/layout/status (`:34`), `DeviceInfo.kind` phone or tablet (`:36`). `identityProvider` is
  `providers/device.dart:37-42`. The name is derived, never stored, so it is the same everywhere.
- Test harness: `pumpApp` fixes the window at 852×393 (`test/support/pump_app.dart:46`), `pumpFaked` takes a child with the
  phone's providers faked (`:79-104`), `settle` pumps twice because `pumpAndSettle` never settles while something animates
  or ticks (`:106-111`, project-notes:114).

### 0.2 party_host, as the phone would use it

- Providers (`packages/party_host/lib/src/providers.dart`): `hostIdentityProvider` `:27` and `hostDirectoriesProvider` `:34`
  throw until an app overrides them; `prefsProvider` `:39` too; `logProvider` `:43` (a 3000-line `LogBuffer` default);
  `advertiserProvider` `:56` (`BonsoirAdvertiser`); `sessionUploaderProvider` `:60` (null); `hostServiceProvider` `:64-76`
  builds `LiveHostService` **and starts it** (`unawaited(service.start())`, `:75`) and disposes it with the container;
  `hostStateProvider` `:78`; `gameHostProvider` `:92`; `gamePlayersProvider` `:95`; `gameSoundsProvider` `:119` (whatever
  watches it keeps the host's sounds playing — the TV's home screen does, `home_screen.dart:28`); `keepAwakeProvider` `:222`
  (the same, `:30`); `screenAwakeProvider` `:218`; `soundPlayerProvider` `:156`; `controlsClaimsProvider` `:244`;
  `localPlayerSourceProvider` `:248` (default: no local player); `puzzleLibraryProvider` `:254` (`PuzzleLibrary.load()`
  from the asset bundle).
- `LiveHostService` (`host_service.dart:77`): everything platform-specific comes through the constructor (`:82-92`), the
  server gets one `WebSocketListener` today (`:106-107`, a comment names the phone's own listener as step 3's addition),
  `state` is computed on read (`:173-186`), `start()` starts the stats, the server, the addresses and advertising
  (`:191-211`), `dispose()` stops everything (`:261-272`), advertising is skipped when the server has no port (`:274-282`)
  and its name is `'Thumb Party TV ($_hostName)'` today.
- `HostIdentity` (`host_identity.dart:9-53`): `appVersion`, `versionLabel`, `hostType` (a `HostType` string), `hostOs`,
  `defaultHostName`. The TV builds it in `tvHostIdentity()` (`tv_test_app/lib/src/tv_host_setup.dart:21-31`).
- The games screen (`ui/games_screen.dart`): `gamesRouteName = '/games'` (`:14`), `GamesScreen` (`:18-85`) is a `Scaffold`
  with an `AppBar` (56 high) and a `ListView` padded 24 (`:28-31`) of two 380×180 cards (`:110-111`) — `pickShapeRace`
  (`:38-44`, `autofocus: true` `:42`) and `pickArena` (`:45-51`), then `openPuzzleSettings` (`:55-60`). `ShapeRaceScreen`
  (`:139`) offers `random-<level>` (`:164-167`, the first `autofocus`) and one card per puzzle (`:171-180`).
- Menus and the remote: `ControllerMenus` (`ui/controller_menus.dart:73-261`) reads every non-simulated, non-local player
  every 16 ms (`:86`), moves the focus (`:226-238`), presses A as `ActivateIntent` on the focused node (`:239-241`) and B as
  `Navigator.maybeOf(focus.context)?.maybePop()` (`:242-247`), and gives every phone `menuLayout` (A "OK", B "Back",
  `:11-21`) while no game claims the controls (`:125-140`). It is `MaterialApp.builder` on the TV
  (`tv_test_app/lib/main.dart:41`).
- Pausing: `Pausable` (`ui/pause_menu.dart:30-126`) opens a menu with `showDialog` (`:110-117`) — **`useRootNavigator`
  defaults to true** — and Quit calls `leaveForGamePicker` (`:123-124`), which pops the **nearest** navigator to
  `gamesRouteName` or the first route (`:129-131`). The menu reads `gamePlayersProvider` and claims the controls
  (`_PauseMenu`, `:133-181`, keys `pauseMenu` `:148`, `pauseQuit` `:168`, `pauseResume` `:174`).
- The join flow: `JoinScreen` (`ui/join_screen.dart:62`) polls inputs every 16 ms (`:110-127`); A joins, the next A starts
  (`:160-175`), `_start()` pushes `PuzzleScreen` on the nearest navigator (`:216-226`), and it makes its local player from
  `localPlayerSourceProvider` in `initState` (`:88`) — the default no-op source is right for a phone.
  `PuzzleScreen` (`ui/puzzle_screen.dart:126-186`) claims `Controls.game()` while playing (`:136-139`) and wraps the play
  view in `Pausable` (`:146-149`).
- Test doubles available to the phone app: `FakeAdvertiser` and `FakeSoundPlayer`, `FakeScreenAwake`
  (`party_host/lib/src/testing/adapter_fakes.dart:56,74`, exported by `party_host/testing.dart`), and the puzzle data
  folder trick (`party_host/test/support/host_harness.dart:161-174`).

### 0.3 The one hard problem: a dialog on the root navigator

`Pausable._pause` calls `showDialog(context: context)` (`pause_menu.dart:110-117`), which builds the dialog **under the
app's root Navigator Overlay** (`useRootNavigator: true` by default). A `ProviderScope` placed inside a pushed route —
which is what the contract's "nested `ProviderScope` with `party_host`'s overrides" describes — sits *below* that Overlay,
so the pause menu cannot see it: it would read the parent container's providers and `hostIdentityProvider` /
`hostDirectoriesProvider` / `prefsProvider` would throw (or, worse, `hostServiceProvider` would build and start a second
`LiveHostService`). This is the decisive constraint on the whole design (§1).

Two ways out, both cost something:

- **Root overrides** (this plan): the party_host inputs are supplied by the app's root `ProviderScope` in `main.dart`, as
  the TV app does (`tv_test_app/lib/main.dart:18-24`). Costs a delegating `hostServiceProvider` override and a state
  object that outlives a host (item 1). Keeps the dialog above the controls, where it looks right and where `Resume`/`Quit`
  can be tapped.
- **`useRootNavigator: false` in party_host** (a one-line change at `pause_menu.dart:111`): the dialog then lives in the
  host route's own navigator, inside the nested scope, exactly as the contract says. Costs a change in s5a's file, puts the
  menu inside the body box *under* the drawn controls (the pad would be painted over it), and lets the pad stay live under
  the dialog — which is the only way `Start`-to-resume works on the phone, since a root-navigator barrier blocks the pad.
  Question 1.

### 0.4 The sizes today

`connect_screen.dart` 412 (over the 400 hard limit today: `ConnectScreen` `:13-49`, `StatusChip` `:51-71`, `_HostList`
`:73-124`, `_NoHosts` `:126-158`, `_ManualEntry` `:160-218`, `ConnectionPanel` `:220-318`, `_CodeEntry` `:320-412`),
`controller_top_bar.dart` 164 (its `build`, `:7-135`, is 129 — a `review.sh` member-length FAIL that s5b owns, STATUS s4),
`controller_screen.dart` 150, `controller_parts.dart` 117, `controls_layer.dart` 44, `main.dart` 33,
`pubspec.yaml` 35; tests `pump_app.dart` 140, `connect_screen_test.dart` 99, `controller_screen_test.dart` 86. Over 300 and
untouched by this job: `layout.dart` 386, `gyro.dart` 351, `diagnostics_screen.dart` 341 (existing debt; s5b adds nothing
to them).

## 1. The provider scope (item 1)

**What the TV overrides** (`tv_test_app/lib/main.dart:18-24`), because the phone has the same problem in a different form:
`prefsProvider` (the loaded `SharedPreferences`), `hostIdentityProvider` (`tvHostIdentity()`), `hostDirectoriesProvider`
(`const TvDirectories()`), `sessionUploaderProvider` (`tvUploader()`), `localPlayerSourceProvider` (`tvKeyboardPlayer`).

**What the phone overrides, and where.** Four in the app's root `ProviderScope` in `main.dart`, through one list so
`main()` and the tests can't drift (new `lib/src/host/host_overrides.dart`, ~45):

| party_host provider | The phone's value | Why here |
| --- | --- | --- |
| `prefsProvider` | the `SharedPreferences` `main.dart:15` already loads — the same instance the controller side uses | the host's `hostId` (`host_service.dart:142`) then survives restarts like the TV's does |
| `hostIdentityProvider` | `phoneHostIdentity(identity)` (`phone_host_setup.dart`): `hostType` `HostType.phone`/`HostType.tablet` from `DeviceInfo.kind`, `hostOs` `Platform.operatingSystem`, `defaultHostName` the controller name (`iPhone 3F2A`), `appVersion`/`versionLabel` from `app_info.dart`, plus s5a's `kind` (`phone`/`tablet`) and `serviceName` ("Thumb Party on `iPhone 3F2A`") | pure data, needed by any host screen or dialog |
| `hostDirectoriesProvider` | `const PhoneHostDirectories()`: sessions under the app support folder (`sessions`, `sessions-debug` in debug builds — the TV's rule, `tv_test_app/src/tv_host_setup.dart:47-51`), exports in the app documents folder (contract §0) | async getters, no disk touch until the host starts |
| `hostServiceProvider` | `ref.watch(phoneServiceProvider)` — `hostingProvider`'s current `PhoneHost.service` | the pause dialog, `hostStateProvider` and the games screen must all see the one running service |

**The one rule this creates:** an always-mounted widget must not read a party host provider before a host exists, because
`party.hostServiceProvider` resolves through `phoneServiceProvider`, which throws. Nothing does today except the host chip,
which returns early until there is a live host (§7).

**Not overridden, and why:** `sessionUploaderProvider` (default null — the phone app has no Firestore project and the
contract asks for none), `localPlayerSourceProvider` (default: no local player — the own player is a real controller, not a
keyboard player), `advertiserProvider`, `soundPlayerProvider`, `screenAwakeProvider` (the real Bonsoir, SoLoud and wakelock;
contract §0 keeps sound in providers), `puzzleLibraryProvider` (loads the bundle), `logProvider` (**not** overridden: the
phone's own 500-line buffer stays the controller's diagnostics log, and party_host keeps its 3000-line one, as on the TV —
folding them together would truncate a host session's log to 500 lines).

**A nested `ProviderScope`, for one thing only:** the host route overrides `clientProvider` with the own player's client
(`clientProvider.overrideWithValue(host.client)`, item 3). Everything else is inherited, so the two containers can never
disagree about the host.

**The name clashes and how imports avoid them.** Three of the phone's providers have party_host twins: `prefsProvider`
(`providers/device.dart:15` vs party `providers.dart:39`), `logProvider` (`providers.dart:20` vs `:43`), `logLinesProvider`
(`providers.dart:30` vs `:142`). Two widget names clash too: `PlayerBadge` (`controller_top_bar.dart:146` vs
`party_host/ui/player_badge.dart`) and `StatusChip`/`ScreenAwake` are close enough to confuse a reader. **Rule: every
`package:party_host/party_host.dart` import in `controller_app` is `as party`** (`import ... as party;`), in `lib/` and in
`test/` alike; `lib/src/providers.dart` stays the single unprefixed import for the phone's own providers. Then
`party.prefsProvider` and `prefsProvider` are visibly different things at every call site, and the override list reads
`party.hostIdentityProvider.overrideWithValue(...)`.

## 2. The host itself: `PhoneHost` and its setup (items 2–3)

**`lib/src/host/phone_host_setup.dart` (new ~95).** Two pure builders, no Riverpod:
- `phoneHostIdentity(ControllerIdentity controller)` — the mirror of `tvHostIdentity()`, from the facts in §0.1, with s5a's
  `kind` and `serviceName`.
- `class PhoneHostDirectories implements HostDirectories` — `sessions()` → `<app support>/sessions[-debug]` (debug
  `kDebugMode`, the TV's rule), `exports()` → `getApplicationDocumentsDirectory()` (contract §0). Needs `path_provider`
  (§8).

**`lib/src/host/phone_host.dart` (new ~150).** The host, with no Riverpod in it, so it can be unit-tested and so the
`live`/`disposed` facts the UI needs are plain fields:

```dart
class PhoneHost {
  PhoneHost({required this.service, required this.listener, required this.presence, required this.client});
  factory PhoneHost.live({required SharedPreferences prefs, required LogBuffer log, required HostIdentity identity,
      required HostDirectories directories, required Advertiser advertiser, required ControllerIdentity controller});
```

- It owns the `InProcessListener` and hands it to `LiveHostService(inProcess: listener)` (s5a), which puts it on the
  `HostServer`; nothing else in the TV's service changes (contract §1).
- `start()`: `await service.start()`, then `client.connect(HostAddress.local(hostId: ..., name: service.state.hostName),
  code: service.state.host.pairingCode)` — awaiting first means the listener is started, so the first attempt succeeds
  (`InProcessListener.connect` throws `ConnectFailed` before `start`, `transport/in_process_listener.dart:27-31`).
- `presence = HostPresence(host: service, onAbandon: _onAbandon, graceS: 30)` (s5a) plus an `AppLifecycleListener`
  (`onHide: presence.hidden`, `onShow: () => unawaited(presence.shown())`). `_onAbandon` pops the host navigator to
  `gamesRouteName` (it needs the navigator handle the host screen gives it; item 6).
- `dispose()`: dispose the client, the presence, the listener, the service, and complete `disposed` (a `Future` the host
  screen awaits to pop itself, item 6). Idempotent, and `live` becomes false.
- **`service` is created in the constructor**, so a provider that reads it never sees a half-built host; `state` is a plain
  getter (`host_service.dart:173-186`), so reading it after `dispose()` is safe.

**`lib/src/host/hosting.dart` (new ~85).** The app's host state, and the only Riverpod glue:
- `final hostingProvider = NotifierProvider<HostingNotifier, PhoneHost?>(HostingNotifier.new);` — `build() => null` (no
  party_host provider is read before a host starts, so the existing widget tests need no new fakes).
- `PhoneHost? start(HostChoice choice)` — builds through `phoneHostBuilderProvider`, sets the state, `unawaited` the
  start, stops discovery (`ref.read(discoveryProvider).stop()`, `discovery.dart:111`), returns the host. On stop it
  restarts it (`restart()`, `discovery.dart:65`), so the Connect screen is searching again.
- `Future<void> stop()` — disposes the current host **but leaves it in the state**. That is deliberate and needs a
  comment: `phoneServiceProvider` returns `state.service`, so a state that went back to null would make every party_host
  provider that watches it rebuild with nothing behind them (Riverpod would throw inside `hostStateProvider`,
  `keepAwakeProvider`, ...). `live` on the object is what the UI asks; `start()` replaces the state, which is exactly the
  one rebuild the graph wants.
- `final phoneHostBuilderProvider = Provider<PhoneHostBuilder>(...)` — the seam for tests, in the same spirit as
  `localPlayerSourceProvider` (`providers.dart:248-251`): the default builds `PhoneHost.live(...)` from
  `party.prefsProvider`, `party.logProvider`, `party.hostIdentityProvider`, `party.hostDirectoriesProvider`,
  `party.advertiserProvider`, `party.sessionUploaderProvider` and the phone's `identityProvider`.
- `final phoneServiceProvider = Provider<HostService>(...)` — `state`'s service, throwing a clear `StateError('No host is
  running in this app')` when nothing has ever started; the override in `host_overrides.dart` points at it.

## 3. The own player (item 4)

**Where the code comes from.** `HostService.state` is a `HostViewState` whose `host` is the server's snapshot
(`host_service.dart:173-186`), and `HostSnapshot.pairingCode` is the live code (`host_server.dart:105-108`, refreshed on
`newPairingCode()`). The phone reads it from the `HostService` it just started — no provider needed, no waiting.

**How the TV's simulated controllers pair, to copy** (`simulated_controllers.dart:46-79`): a `ControllerClient` with a
`ControllerIdentity(controllerId: 'sim-…', name: 'Simulated controller', platform: 'sim')` and a `WebSocketConnector`
(`:60`), connected with `client.connect(HostAddress(addresses: ['127.0.0.1'], port: port), code: pairingCode)` (`:75-78`).
The phone's own player is the same shape with an in-process connector:

```dart
final client = ControllerClient(identity: controller, connector: InProcessConnector(listener), log: log.sink('own'));
client.connect(HostAddress.local(hostId: controller.controllerId, name: state.hostName), code: code);
```

- `InProcessConnector` requires `target.isLocal` and opens the link through the listener
  (`transport/in_process_connector.dart:20-21`); `HostAddress.local` has no addresses and port 0
  (`host_address.dart:17-18,98-99`).
- **The hostId is a placeholder and it is harmless**: the welcome replaces the target's hostId with the host's own
  (`client_messages.dart:116`), the token is saved under that real id (`:141-143`), and this client is built with no
  `onTokenChanged` and no tokens, so nothing is persisted for the own player and it asks for the code every time, like the
  sims. (Exposing `HostService.hostId` would be tidier; Question 2.)
- **The identity it sends** is the phone's own `ControllerIdentity` (`storage.dart:16-42`): `controllerId` (16 random hex),
  name `iPhone 3F2A`, platform/`appVersion`, capabilities metrics/rating/layout/status, `DeviceInfo` kind + screen size
  (once `withDeviceDetails` has answered, `storage.dart:45-58`). So the host's lobby shows the phone itself as P1, with
  `ControllerInfo.isLocal` true because its channel is the link (contract §0) — which is what step 8 reads for "watched on
  the host phone".
- What the capabilities bring with them: `layout` and `status` are how the own player's pad shows the menus' buttons and
  the game's labels; `metrics` means the own touch metrics go to the host's stats (honest in-process numbers); `rating`
  means the host will ask the own player "How did the controls feel?" after a game — over its own game. That is odd, not
  broken; §6 skips the prompt in host mode (Question 5).

## 4. The entry: "Host a game" and the start sheet (item 5)

**`connect_screen.dart` 412 → ~225, plus `connect_panels.dart` (new ~215) — a pure move first, then the button.** The file
is already over the 400 hard limit, so it splits before it grows (coding-guidelines:39):
- `ConnectionPanel` (`:220-318`) and `_CodeEntry` (`:320-412`) move to `lib/src/ui/connect_panels.dart` (plain sibling
  library, not a `part`: project-notes:51), with the imports they need. `StatusChip` stays (it is public and used by
  `ConnectScreen`'s own `build`, `:27`).
- `ConnectionPanel`'s idle branch gains the button below "Try without a TV" (`:241-249`), and the failed branch the same
  one (`:299-307`) — no TV answering is exactly when hosting helps. One private `_HostGameButton` used twice (~14 lines):
  `OutlinedButton.icon(key: Key('hostGame'), icon: Icons.wifi_tethering, label: Text('Host a game'))`.
- `showHostStartSheet(context)` → `Future<HostChoice?>`: a dialog titled "Host a game" (`Key('hostStartSheet')`, landscape,
  so a dialog not a bottom sheet) with two big choices — "Play on this phone" (`Key('hostOnPhone')`, default: `autofocus`
  and the primary style) and "Show on this device" (`Key('hostOnDevice')`), each with one line of explanation ("Play here
  with the controls on the screen" / "Everyone joins from their phones; this phone shows the game") — and "Cancel"
  (`Key('hostCancel')`). `enum HostChoice { onPhone, onDevice }` lives with it (`lib/src/host/host_start_sheet.dart`,
  ~90).
- On a choice: `final host = ref.read(hostingProvider.notifier).start(choice);` then
  `Navigator.of(context).push(MaterialPageRoute(builder: (_) => HostScreen(host: host, choice: choice)))`. `ConnectScreen`
  stays below: "Stop hosting" pops back to it, which is what the contract's "returns to `ConnectScreen`" says, and the
  Connect screen is then already searching again (item 1).

## 5. The host screen: the background, the games navigator, C34 (item 6)

**`lib/src/host/host_screen.dart` (new ~120)** — the route's widget:
- `ref.watch(party.gameSoundsProvider)` and `ref.watch(party.keepAwakeProvider)` (the TV's home screen does exactly this,
  `home_screen.dart:28-30`): without them a hosted game is silent and the phone may sleep, because the phone has no home
  screen to keep them alive.
- `gameShownProvider` true: `late final _gameShown = ref.read(gameShownProvider.notifier);` in `initState`, `set(true)` in
  the first post-frame, `set(false)` in `dispose` (project-notes:112: a `late final` that needs `ref` is set in
  `initState`, so `dispose` never touches `ref`). True is what makes the controls take the saved opacity over the game and
  the bar show the ping instead of the status panel (`controller_parts.dart:23-25`, `controller_top_bar.dart:13-16`).
- One `ProviderScope` built once (`late final Widget _body = ProviderScope(overrides: [clientProvider.overrideWithValue(
  widget.host.client)], child: party.ControllerMenus(child: ControllerScreen(background: const HostGames(),
  controls: widget.choice == HostChoice.onPhone)))`), so a rebuild of `HostScreen` can never hand Riverpod a new override
  list.
- `party.ControllerMenus` wraps the screen (as `MaterialApp.builder` does on the TV, `tv_test_app/lib/main.dart:41`), so the
  own player's D-pad/A/B work every party_host screen. It reads `gameHostProvider` and `controlsClaimsProvider` from the
  nested container, which inherits the root overrides — the same instances the pause dialog reads from the root.
- `PopScope(canPop: false, onPopInvokedWithResult: ...)` → a system back press stops the host instead of popping the route
  and leaving a server running. "Stop hosting" (and the back press) = `hosting.notifier.stop()`; the screen pops itself
  when `host.disposed` completes.
- The `HostPresence`'s abandon callback needs the navigator the games live in: `HostScreen` owns a
  `GlobalKey<NavigatorState>` for `HostGames` and passes `onAbandon: () => key.currentState?.popUntil(...gamesRouteName)`.

**`lib/src/host/host_games.dart` (new ~45)**: the body the controls sit on.
```dart
Navigator(key: key, onGenerateRoute: (_) => MaterialPageRoute<void>(
  settings: const RouteSettings(name: party.gamesRouteName), builder: (_) => const party.GamesScreen()));
```
- **Its size** is the body box: `_Controls` fills `Expanded` under the 52-high bar, so the games screen gets 852×341 on the
  test phone and `tester.getRect(GamesScreen) == tester.getRect(ControlsLayer)` is an invariant a test can state.
  The games screen's own `AppBar` (56) takes the top of that, leaving 285 for the cards, which is why the two 380-wide
  cards still fit side by side (380+24+380 = 784 ≤ 852−48 = 804) and the second row scrolls.
- **Why a nested navigator**: the phone has one navigator; without this the first `_open` (`games_screen.dart:87-88`) would
  cover the bar and the controls. With it, `Navigator.of(context)` inside every party_host screen (including
  `JoinScreen._start` `:216-226` and `PuzzleScreen._replaceWith` `:116-118`) resolves to the body, and the bar and the
  controls stay on top.
- **The pause menu's Quit route**: `leaveForGamePicker` pops the *nearest* navigator until `gamesRouteName` or the first
  route (`pause_menu.dart:129-131`). Our initial route is named `gamesRouteName`, and it is also the first route, so both
  tests pass and Quit lands on the game picker inside the body. (The `RouteSettings.name` is what makes that explicit
  rather than accidental.)
- **Focus and keyboard handlers on a phone**: `GamesScreen`'s `CallbackShortcuts` for Escape (`games_screen.dart:25-26`)
  waits for a key event that never comes on a phone — harmless. The card's `autofocus: true` (`:42`) is what
  `ControllerMenus` steers, and nothing above it asks for the focus first, so it holds it (project-notes:115: autofocus
  loses only when something above it has the focus — the `JoinScreen`/`PuzzleScreen` screens move it deliberately,
  `join_screen.dart:89-92`, `puzzle_screen.dart:107-112`, and inside the nested navigator that stays inside our body). The
  `PuzzleScreen`'s `Focus(autofocus: true, onKeyEvent: _onKey)` (`puzzle_screen.dart:136-137`) is the same: no keyboard
  on a phone, no effect.
- **What the bars cost**: the app's own bar (~52) plus the games screen's `AppBar` (56) is 108 of 393 logical pixels on a
  landscape phone. Cramped but workable, and `PuzzleScreen` has no `AppBar` at all (its `Scaffold(body: SafeArea(...))` is
  `puzzle_screen.dart:143-144`), so the game itself gets the full body. Question 6 asks whether the party_host screens' own
  `AppBar`s should be hidden in host mode.
- **Touches**: the controls take only their own areas (`_PointerArea` is a `Listener`, `pad_widgets.dart:16,30`), so a
  touch between them reaches the games screen. On a 852×341 body the D-pad square is x 25-342 and the face buttons
  x 510-827, which covers most of the picker's left card — so the *reliable* way to work the host's screens on the phone is
  the own player's buttons through `ControllerMenus`, which is what the G3 test does (§9).

**C34, "Show on this device"** is the same screen with `controls: false`: `_Controls` returns the background alone (no
layer, no touch metrics `Listener`, no demo readout), and the bar keeps only the host chip and Diagnostics (§7).

## 6. What `ControllerScreen` (and its bar and providers) do on start, and how host mode switches each off (item 7)

`ControllerScreen` gains two optional parameters — `Widget? background` (the `ControlsLayer` child) and `bool controls =
true` — and one derived fact, `bool get _hosting => widget.background != null`, with a doc comment ("a background means
this app is hosting"). "In host mode" for the *other* `ControllerScreen` (the controller one, still alive below
`ConnectScreen` and the host route) is `ref.read(hostingProvider)?.live == true`; in `build` it is `ref.watch(...)` so the
listeners come and go with the state.

| What happens today | Where | In host mode | How it is switched off |
| --- | --- | --- | --- |
| `reconnectToLastHost()`, else `openConnect(context)` | `:44` | neither: the own client is already connecting, and there is no `ConnectScreen` | `if (_hosting) return;` before it in the post-frame callback (1 line) |
| `sessionMonitorProvider.start()` | `:47` | no: the battery/CPU sampler is the controller-side's, and the host has its own stats (`statsServiceProvider`) | `if (!hosting) ref.read(sessionMonitorProvider).start();` |
| `gyroProvider.restoreMode()` | `:46` | yes: the saved pad mode is the own player's | kept |
| `discoveryProvider.restart()` on resume | `:62` | no: nothing to find, and Bonsoir browsing is exactly what should stop | `if (!hosting) ...`; and the host's start calls `discovery.stop()` (item 1) |
| `clientProvider.resume()` on resume | `:66` | yes: the in-process link may have been replaced while asleep (`controller_client.dart:233-243`) | kept — it resumes the *nested* client |
| gyro/haptics pause, `padProvider.releaseAll()` | `:71-73` | yes, more so | kept |
| `clientStateProvider` → `discovery.restart()` every 4th attempt | `:105-109` | no | wrap the `ref.listen` in `if (!hostMode)` |
| `discoveryStateProvider` → `client.updateAddress` | `:111-116` | no — and this watch is what *creates* `discoveryProvider` (`providers/connection.dart:12-17`) | wrap it in `if (!hostMode)`; then no code path in host mode ever builds it |
| `ref.listen(tvHapticsProvider)` | `:101` | yes: the host fires haptics at its own player, and the phone's own haptics player plays them | kept |
| `ref.listen(outagesProvider)` | `:102` | yes (connection health of the own client) | kept |
| `phoneMetricsProvider` (touch metrics) | `:122` | yes for "Play on this phone" (they are the own player's metrics); no for C34 | comes with `controls` (§5) |
| `_followTheGame`: game layout | `:82-90` | yes, and it is what labels the pad with the host's buttons | kept |
| `_followTheGame`: the rating prompt | `:92-94` | **no**: a dialog on the root navigator over your own game, and a self-rating in the stats | `if (!hosting)` around that `ref.listen` (Question 5) |
| `_TopBar`: the connection chip opens `ConnectScreen` | `:35-48` | replaced by the host chip (§7) | the bar takes `hosting` |
| `_TopBar`: mode buttons, gyro/stick, Settings | `:69-131` | only with controls (they configure the own player's pad) | the bar takes `controls` |

Nothing else in the app watches `clientProvider` in a way that breaks: `gameLayoutProvider`, `gameStatusProvider`,
`tvHapticsProvider`, `ratingPromptProvider`, `phoneMetricsProvider` and `sessionMonitorProvider` all live inside the host
route's scope (the first four) or are guarded (`sessionMonitorProvider`); the controller screen below keeps the TV client.

## 7. The top bar: the split and the host chip (item 8)

**`controller_top_bar.dart` 164 → ~55; `bar_connection.dart` (new ~80) and `bar_modes.dart` (new ~85).** Extracted widgets go
in plain sibling files (project-notes:51), so the two are public:
- `BarConnection` — `PlayerBadge`, the chip, the status panel or ping stats; moves `:8`, `:11-21`, `:30-64` with
  `_statusColor` (`:138-143`) and `PlayerBadge` (`:146-164`). Prints the own player's number and the host's name in chip
  form: `Thumb Party on iPhone 3F2A · 0 ms` — which is true over the link.
- `BarModes` — the `SegmentedButton` and the two tune buttons (`:69-119`), with `gameLayoutProvider`/`gyroProvider`.
- `_TopBar` keeps the `Padding`/`Row` and picks: `hosting ? const HostChip() : const BarConnection()`, then
  `if (controls) const BarModes()`, then `if (controls) Settings`, always Diagnostics. `build` lands near 45 lines with a
  3-line doc comment, well under the 60 the review wants (STATUS s4).

**`lib/src/ui/host_chip.dart` (new ~120).** `ActionChip(key: Key('hostChip'))` with a green dot and `Hosting · <code>`
(read from `party.hostStateProvider`), opening a `MenuAnchor` that is the host's menu: the pairing code large
(`Key('hostCode')`), the first local address (`Key('hostAddress')`, `state.addresses`, `party/host_view_state.dart`), "New
code" (`Key('newCode')` → `service.newPairingCode()`), and "Stop hosting" (`Key('stopHosting')` → `hosting.stop()`). Without
it nobody could join a phone-hosted game: the TV shows the code on its home screen, and the phone has no home screen.
Question 4.
**It must read `hostingProvider` first and return a `SizedBox.shrink()` when that is null or not `live`**, before it
watches `party.hostStateProvider`: that provider watches `hostServiceProvider` (`providers.dart:78-89`), which the phone
overrides with `phoneServiceProvider`, which throws until a host exists — and the bar is built on every screen. A
state-dependent `ref.watch` after that early return is fine (the watch set only grows when the state does). Nothing else
that is always mounted reads a party host provider: `gameSoundsProvider` and `keepAwakeProvider` are watched only by the
host screen, and `gameHostProvider`/`controlsClaimsProvider` only by `ControllerMenus`, which only the host route mounts.

## 8. pubspec, iOS and Android: what is sure, what isn't (item 9)

**`controller_app/pubspec.yaml` 35 → ~44.** `party_host` (path `../packages/party_host`) and `path_provider: ^2.1.6` (the
same version the TV app uses, `tv_test_app/pubspec.yaml:31`). The contract also lists `game_kit`, `puzzle_game`, `test_game`
and `game_assets`: they are all `party_host`'s own dependencies and a workspace member's assets are bundled through it, so
naming them again would only add unused direct dependencies — the phone imports nothing from them (Question 3).
`bonsoir` is already a direct dependency (^7.1.5, `:14`), so advertising is the same package the app already browses with.

**Sure:**
- **Android needs no new permission.** The TV app advertises today (contract §1, M12 design §2.6) with exactly the three
  permissions the phone already declares — `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
  (`android/app/src/main/AndroidManifest.xml:2-6`, whose comment says Android 16 needs no runtime permission for this on
  Android 12 and later, vs the TV's identical set) — and no `NEARBY_WIFI_DEVICES`. That permission guards the Wi-Fi scan /
  Aware / RTT APIs, not `NsdManager`. `VIBRATE` is already there (`:8`), and `WAKE_LOCK` for `wakelock_plus` arrives
  through the plugin's manifest merge — the TV app has no `WAKE_LOCK` line either and keeps its screen on.
- **minSdk and the iOS target already cover every new plugin**: `minSdk = 31` (`android/app/build.gradle.kts:35`) and
  `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (`ios/Runner.xcodeproj/project.pbxproj:363,490,542`) are far above what
  `flutter_soloud 5.2.1`, `bonsoir 7.1.5` and `path_provider 2.1.6` ask for, so no gradle or Podfile change. The
  `flutter_soloud` prebuild tag is already pinned at the workspace root (`pubspec.yaml:24-27`), which the phone app joins
  by being a workspace member.
- **iOS needs no Info.plist change for advertising.** `NSLocalNetworkUsageDescription` (`ios/Runner/Info.plist:29-30`) and
  `NSBonjourServices = [_gamectl._tcp]` (`:31-34`) are already there for *browsing*, and iOS uses the same list for
  advertising a type; `_gamectl._tcp` is `serviceType` (`packages/protocol/lib/src/network.dart:6`), which s5a's
  `HostIdentity.serviceName` will now use for the host's name. No `UIBackgroundModes` (contract §0: no background time).
- **No Android manifest change at all**, which is the whole point of the list above.

**Unsure (device checks, not code):**
- Whether a *phone* may advertise with NSD in practice (power management, the app being hidden, iOS's local-network prompt
  once rather than per session): contract §0 Q7 calls it unproven, and the step 5 exit (solo, Wi-Fi off) doesn't need it.
  The screen check is "the iPad sees the iPhone's game in its host list".
- Whether `flutter_soloud` initialises on the same phone that is drawing the game (CPU and the audio session, plus the
  phone's silent switch): it is the same player the TV uses, contract §0 keeps it in providers, and the device check proves
  it. If it fails, the fallback is a `FakeSoundPlayer`-shaped no-op in `host_overrides.dart` until it's fixed — no
  party_host change.
- Whether the host's `AudioSession`/`flutter_soloud` and the phone's own haptics fight: no reason to think so, untested.

## 9. The G3 slice: one path, end to end, as a widget test (item 10)

**The path**: `ControllerScreen` → no last TV → `ConnectScreen` → "Host a game" → "Play on this phone" → the games screen
behind the controls with the own player paired **on the in-process link only** → Shape Race solo starts.

**Slices S0 and S1** (§11) are G3. **`test/support/host_app.dart` (new ~160)** is the harness:
`pumpHostApp(tester)` = `pumpFaked` with the phone's fakes (`FakeClient`, `FakeDiscovery`, `FakeHaptics`,
`FakeMotionSensors`, `FakeDeviceStatus`) **plus**:
- `phoneHostOverrides(prefs: prefs, log: log, identity: phoneHostIdentity(identity), directories: TempHostDirectories())`,
  the same list `main()` uses (`pumpFaked` gains one `List<Override> extra = const []` parameter, 140 → ~145);
- `party.advertiserProvider.overrideWithValue(FakeAdvertiser())`, `party.soundPlayerProvider.overrideWithValue(
  FakeSoundPlayer())`, `party.screenAwakeProvider.overrideWithValue(FakeScreenAwake())` (all from
  `package:party_host/testing.dart`);
- `party.puzzleLibraryProvider.overrideWith((ref) async => testPuzzles())` — a local `testPuzzles()` that reads
  `../packages/puzzle_game/puzzles/index.json` (party_host's own helper, `host_harness.dart:168-175`, is private and its
  relative path assumes its own package);
- `TempHostDirectories` (~15): a class implementing `HostDirectories` over `Directory.systemTemp.createTempSync()`, so the
  stats never write into the developer's home folder;
- small helpers: `tapFace(tester, ControllerButton.a)` (the `game_controls_test.dart:57-61` idiom),
  `faceLabels(tester)` (the semantics label of `Key('faceButtonLabels')`), `enterHostMode(tester)` (tap `hostGame`, then
  `hostOnPhone`).

**Why the real `LiveHostService` and not a fake `HostService`**: the contract allows either, and the real one needs no
socket for the own player — `HostServer.port` is null when every listener is port-less (`host_server.dart:111-117`), so
with the `WebSocketListener` that the service adds, it binds a localhost port but only the in-process link is used. The
test proves the real wiring (identity, directories, stats, the code, the link) instead of a double that could drift. The
`FakeAdvertiser` keeps mDNS out of `flutter test`.

**The test** (`test/host_mode_test.dart`, ~190, first case):
1. `pumpHostApp` → `ConnectScreen` (no `lastHost` in the mock prefs, `pump_app.dart:53`).
2. Tap `Key('hostGame')` → the sheet (`Key('hostStartSheet')`) with both choices → tap `Key('hostOnPhone')` → `settle`.
3. The host screen: `find.byType(party.GamesScreen)` findsOneWidget **inside** the body:
   `expect(tester.getRect(find.byType(party.GamesScreen)), tester.getRect(find.byType(ControlsLayer)))` (both 852×341 on the
   test window, bar ≈52: `Padding` top 4 + a 48-high `IconButton` row), and `find.byKey(Key('pickShapeRace'))`.
4. The own player paired, in-process only: `host.service.state.host.controllers` has one entry with `isLocal` true, and
   `host.service.gameHost.players.single.number == 1`; the bar shows `Key('playerBadge')` with `P1`; the pad is labelled with
   the menus: `faceLabels(tester)` contains `'A OK'` and `'B Back'` (the round trip client → host → `ControllerMenus` →
   layout → client → pad).
5. Press A on the pad: `tapFace(tester, ControllerButton.a)` (`FaceGeometry.classic.centers[a]` is (0.5, 0.81) of the
   faceButtons square, i.e. (668.5, 264.8) on this window) + `pump(20 ms)` for `ControllerMenus`' 16 ms tick + `settle` →
   `ShapeRaceScreen` (`random-easy` has the focus). A tap on the card itself is **not** usable: its centre (214, 170) is
   30.7 px from the D-pad's centre against a 31.7 px dead zone (`dpadDirection`'s `deadZone = 0.2` × a 317 px side,
   `pad.dart:198-207`), so whether it also presses the D-pad depends on 1 px of layout.
6. A again → `JoinScreen`; A joins; A again starts → `PuzzleScreen` with `{ownPlayerId: PuzzleSide.left}` and the play view
   running; the body rect is unchanged (the puzzle is still inside the body box, behind the controls).
   **The fakes this needs**: `FakeAdvertiser`, `FakeSoundPlayer`, `FakeScreenAwake`, `TempHostDirectories`, `testPuzzles()`,
   and the phone's existing ones. No `FakeHostService` (Question 7).

## 10. The G4 rest and its tests (item 11)

**S2 — C34 and leaving.** "Show on this device" (`HostChoice.onDevice`): `find.byType(ControlsLayer)` findsNothing, no
`playerBadge`, the games screen still fills the body, and the bar has the host chip but no mode buttons. "Stop hosting"
(`Key('stopHosting')` in the chip's menu, and the system back press) → back to `ConnectScreen`
(`find.byType(ConnectScreen)`), `host.live == false`, the own client disconnected
(`client.snapshot.status == ClientStatus.idle`), and `FakeDiscovery.restarts` went up by one (the search resumes).
A second "Host a game" after stopping works again (`start` replaces the state and the graph rebuilds on the new service) —
the test that proves the "keep the dead host" decision of item 1 is safe.

**S3 — the lifecycle and the switch-offs** (`test/host_lifecycle_test.dart`, ~110):
`test/host_lifecycle_test.dart` drives `tester.binding.handleAppLifecycleStateChanged` with `resumed` while hosting: the
`FakeDiscovery`'s `restarts` and `stops` stay unchanged (the ControllerScreen below is guarded, §6) and `FakeClient` gets no
`connect`/`resume`; then `hidden` → `present` → `shown`: `hostAwayProvider` (s5a) is true while hidden and false after
shown, and `service.resume()` was called once (a fake `HostService` would need `resume()`, so this test uses the real
service and reads the log, or counts through `FakeHostService` if s5a's fake lands with a counter — Question 8).
If `AppLifecycleListener` doesn't see the synthesized transitions in a widget test, the same assertions run by calling
`host.presence.hidden()`/`shown()` directly, and the listener wiring stays a device check.

**S4 — the host state and the entry** (`test/hosting_test.dart`, ~110, a `ProviderContainer` test, no widgets):
`phoneServiceProvider` throws before a host exists; `start(onPhone)` returns a host whose client is connected over the link
(`await pumpEventQueue()`), with `service.state.host.running` true and one local controller; `stop()` leaves `live` false,
disposes the client and the service (a second `stop()` is a no-op); a second `start` gives a new host and new provider
instances (`container.read(hostServiceProvider)` differs). Plus `test/connect_screen_test.dart` 99 → ~135: "Host a game" is
offered while not connected and while a connection failed, the sheet opens with both choices and the phone one focused,
Cancel closes it and starts nothing (`hostingProvider` stays null).

**Where the contract's §4 controller_app cases land:** "Host a game" → the games screen behind the controls with the own
player paired = S1 (G3); "Show on this device" → no controls = S2; "Stop hosting" disposes the host = S2.

## 11. Every file, size now → after, in order

| # | File | Now | After | Slice | Why |
| --- | --- | --- | --- | --- | --- |
| 1 | `controller_app/lib/src/ui/connect_panels.dart` | new | ~215 | S0 | `ConnectionPanel` `:220-318` + `_CodeEntry` `:320-412`, moved; the host button |
| 2 | `controller_app/lib/src/ui/connect_screen.dart` | 412 | ~225 | S0 | over the hard limit: two widgets out, the host button in |
| 3 | `controller_app/lib/src/ui/bar_connection.dart` | new | ~80 | S0 | `PlayerBadge`, the chip, the status/ping area, `_statusColor` |
| 4 | `controller_app/lib/src/ui/bar_modes.dart` | new | ~85 | S0 | the mode `SegmentedButton` and the two tune buttons |
| 5 | `controller_app/lib/src/ui/controller_top_bar.dart` | 164 | ~55 | S0 | `_TopBar` picks the pieces; `build` under 60 |
| 6 | `controller_app/lib/src/ui/controller_parts.dart` | 117 | ~123 | S0/S1 | `_Controls` takes `background`/`controls`, passes the child, returns early for C34 |
| 7 | `controller_app/pubspec.yaml` | 35 | ~44 | S1 | `party_host`, `path_provider` |
| 8 | `controller_app/lib/src/host/phone_host_setup.dart` | new | ~95 | S1 | `phoneHostIdentity`, `PhoneHostDirectories` |
| 9 | `controller_app/lib/src/host/phone_host.dart` | new | ~150 | S1 | the host, the link, the presence, the lifecycle |
| 10 | `controller_app/lib/src/host/hosting.dart` | new | ~85 | S1 | `hostingProvider`, the builder seam, `phoneServiceProvider` |
| 11 | `controller_app/lib/src/host/host_overrides.dart` | new | ~45 | S1 | the four party_host overrides, shared by `main()` and the tests |
| 12 | `controller_app/lib/src/host/host_screen.dart` | new | ~120 | S1 | the route: scope, menus, sounds, screen-on, `gameShown`, back press |
| 13 | `controller_app/lib/src/host/host_games.dart` | new | ~45 | S1 | the nested navigator, `gamesRouteName` |
| 14 | `controller_app/lib/src/host/host_start_sheet.dart` | new | ~90 | S1 | `HostChoice` and the sheet |
| 15 | `controller_app/lib/src/ui/host_chip.dart` | new | ~120 | S1 | code, address, new code, Stop hosting |
| 16 | `controller_app/lib/main.dart` | 33 | ~30 | S1 | the override list, through `host_overrides.dart` |
| 17 | `controller_app/lib/src/ui/controller_screen.dart` | 150 | ~175 | S1 | `background`/`controls`, the guards of §6 |
| 18 | `controller_app/test/support/pump_app.dart` | 140 | ~145 | S1 | `pumpFaked(..., extra:)` |
| 19 | `controller_app/test/support/host_app.dart` | new | ~160 | S1 | the harness, `TempHostDirectories`, `testPuzzles()`, `tapFace` |
| 20 | `controller_app/test/host_mode_test.dart` | new | ~190 | S1/S2 | the G3 path, then C34 and Stop hosting |
| 21 | `controller_app/test/host_lifecycle_test.dart` | new | ~110 | S3 | the switch-offs and `away` |
| 22 | `controller_app/test/hosting_test.dart` | new | ~110 | S4 | start/stop, the provider, the second host |
| 23 | `controller_app/test/connect_screen_test.dart` | 99 | ~135 | S4 | the button and the sheet |

**Nothing is over 300 after**: the largest new file is `connect_panels.dart` ~215 (a pure move of two widgets that were
already one responsibility: "the right-hand side of the Connect screen"), then `host_mode_test.dart` ~190 (a test file, and
its second and third cases are the G4 ones — if it reaches 300 they split by concern: the entry and the host screen).
`controller_screen.dart` ~175 and `phone_host.dart` ~150 are the two that carry the most new work and both have room.
**Order** (each slice leaves the workspace compiling and its checks green, `tools/check.sh` names in brackets):
**S0** files 1-6 (`format analyze phone`) → **S1** files 7-20 (`format analyze phone host`) → **S2** file 20's rest
(`phone`) → **S3** file 21 (`phone`) → **S4** files 22-23 (`phone`). S1 needs s5a's `LiveHostService(inProcess:)`,
`HostIdentity.kind`/`serviceName`, `HostType.tablet` and `HostPresence`/`hostAwayProvider`; S3 needs `hostAwayProvider`.
`format analyze` must be clean after every slice; `tv`, `host`, `connection`, `metrics`, `kit`, `arena`, `puzzle` are
untouched by s5b and must stay green (no file of theirs changes).

## 12. Conflicts with the contract and with s5a

1. **"The host screen: a nested `ProviderScope` with `party_host`'s overrides" (§3) vs the pause dialog** (§0.3). A nested
   scope cannot serve a dialog on the root navigator. This plan puts the four overrides at the app's root and keeps a nested
   scope for `clientProvider` only. Question 1.
2. **`hostServiceProvider` cannot be a const value**: the phone's host does not exist at app start, so its override reads
   `phoneServiceProvider`, which reads `hostingProvider`. The "keep the last host in the state" rule (item 1) is what makes
   that override not throw when a host stops. It is a mechanism the contract doesn't describe; Question 1 covers it with the
   alternative.
3. **`HostPresence.onAbandon` is the caller's callback (§2)**, but "records `round_end` with `reason: abandoned`, its view
   ends `abandoned`" (§2) is a session/puzzle concern (`puzzle_game/lib/src/puzzle_report.dart:58` writes `round_end`;
   `ViewEndReason.abandoned` is `protocol/lib/src/view.dart:120`). The phone can only pop the games navigator; if s5a does
   not record the abandonment itself, the phone will pass a callback that just pops and the recording stays open.
   Question 8.
4. **The contract's `HostService` (abstract, §2) has `resume()` but no exposure of the host's id**, and the own player needs a
   `HostAddress.local(hostId: …)` (`host_address.dart:17-18`). The welcome replaces it before anything is saved
   (`client_messages.dart:116,141-143`), so a placeholder works; exposing `hostId` on `HostService` would be tidier.
   Question 2.
5. **The contract lists five new dependencies** (`party_host`, `game_kit`, `puzzle_game`, `test_game`, `game_assets`); only
   `party_host` and `path_provider` are imported. Question 3.
6. **s5a is in flight** and touches `host_service.dart`, `providers.dart` (adding `resume`, `inProcess`, `hostAwayProvider`,
   `kind`, `serviceName`), `pause_menu.dart` and `host_fakes.dart`. s5b's plan touches none of those files, so a merge is
   clean; but S1 cannot compile until the names exist (STATUS: "s5b (phone app) after s4" — and after s5a).
7. **The contract's `HostPresence` shape has no place to hang the phone's `AppLifecycleListener`**; §3 says the phone owns
   both, which is what item 3 does — no conflict, noted so it isn't built twice.

## 13. Questions

1. **The scope: root overrides, or `useRootNavigator: false` in party_host?** (Conflicts 1 and 2.) *Proposed: the root
   overrides as written. The dialog stays where a dialog belongs (above the bar and the controls, tapping Resume/Quit
   works), no party_host file changes under s5a, and the one oddity — a stopped host stays in `hostingProvider`'s state —
   is local to one file. The alternative costs one line in `pause_menu.dart:111` and gives `Start`-to-resume (the pad stays
   live under a dialog it is also drawn over); say if you'd rather have that trade.*
2. **The own player's `hostId`.** *Proposed: a placeholder (the phone's own controller id) — the welcome replaces it before
   anything is saved, and the own client keeps no tokens. If you'd rather, s5a can add `String get hostId` to `HostService`
   (one line on `LiveHostService`, it already has it privately at `host_service.dart:154`).*
3. **The pubspec.** *Proposed: `party_host` and `path_provider` only; `game_kit`, `puzzle_game`, `test_game` and `game_assets`
   arrive through `party_host` and their assets bundle anyway. Say if the "depends on" line in §3 was meant literally (five
   unused direct dependencies).*
4. **Where the pairing code is shown.** The TV shows it on its home screen; the phone has no home screen, so "Show on this
   device" (whose whole point is other phones joining) would show none. *Proposed: the host chip in the top bar —
   `Hosting · 0427`, opening a menu with the code, the first address, "New code" and "Stop hosting". Say if you want it
   somewhere louder (a full-width banner under the bar outside a game).*
5. **The rating prompt in host mode.** *Proposed: skipped (`_followTheGame`'s second listener). The own player is offered a
   rating by the host it runs, which would ask the player how their own game felt and put it in the session's stats. Say if
   you want it kept.*
6. **Two bars on a 393-high screen** (the app's 52 and party_host's 56 `AppBar`). *Proposed: keep both for G3/G4 and let
   the look-and-sound pass decide; hiding the party_host `AppBar`s on the phone would be a party_host change (a
   `showBar`/`embed` flag) and it is not in §3.*
7. **A real `LiveHostService` in the widget test** (a localhost port bound, the in-process link as the only client).
   *Proposed: yes — it is the smallest honest test of the real wiring, and `HostServer` binds no port when all listeners are
   port-less, which is what a fake `HostService` would have to fake anyway (its players, its pairing code, its link).*
8. **`HostPresence` and abandonment** (conflict 3). *Proposed: `PhoneHost` passes a callback that pops the games navigator to
   `gamesRouteName`; s5a records `round_end`/`abandoned` and ends the view (its own layer knows the session), and its
   `FakeHostService` counts `resume()` so the phone's lifecycle test can assert it.*
9. **`ControllerScreen`'s two new parameters** (`background`, `controls`) *Proposed: as named, with `background != null`
   meaning "this app is hosting" — one documented invariant instead of a third flag. Say if you'd rather have an explicit
   `hosting` bool.*
