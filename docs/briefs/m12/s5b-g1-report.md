# M12 step 5b — G1 report: host mode in the phone app

Brief: [s5b-g1.md](s5b-g1.md). Plan: [s5b-g1-plan.md](s5b-g1-plan.md). Contract: [m12-host-mode.md](../design/m12-host-mode.md)
(wins). Gate: **G1 only** — no code was written or changed.

## What I did

1. Read the brief, the contract §0-§6, [s5-g0-survey.md](s5-g0-survey.md), [s5a.md](s5a.md) and the s5b summary in
   [STATUS.md](STATUS.md), then the files the plan has to answer for: `ControllerScreen` and its parts, the top bar, the
   Connect screen, the providers, `main.dart`, `storage.dart`, `layout.dart`, `pad.dart`, `pad_widgets.dart`, and on the
   host side `party_host`'s providers, `HostService`, `HostIdentity`, `HostDirectories`, the games/pause/menus/join/puzzle
   screens, the fakes, and `packages/connection`'s in-process listener/connector, `HostServer`, `HostAddress`,
   `ControllerClient`, `client_messages`.
2. Wrote the plan in the shape of [s3c-b-g1-plan.md](s3c-b-g1-plan.md): §0 facts with file:line, then the items the brief
   asks for (scope, host, own player, entry, host screen, the switch-offs, the bar split, pubspec/platforms, the G3 slice,
   the G4 rest), then the file table with sizes and order, the conflicts and the questions.
3. Checked the line numbers I cite: every `file:line` in the plan was read back (see "Checks" below), and the dozen that
   had drifted from my earlier notes were corrected before handing over (`discovery.dart` 61 → 111/65,
   `host_service.dart` 152 → 154, `join_screen.dart` 82-86 → 89-92, `puzzle_screen.dart` 110-114/140-145 → 107-112/136-137,
   `pad_widgets.dart` 16-38 → 16,30, the Android manifest 2-7/9-10 → 2-6/8, `pubspec.yaml` 23-27 → 24-27,
   `providers.dart` 246-251 → 248-251, the transport line ranges).

No source file, test, pubspec or platform file was touched: the job is a plan, and the only files I changed are this
report and the plan.

## The facts that decided the design

- **s5a has not landed.** `git status --short` shows nothing under `packages/`; `grep` finds no `resume`, `HostPresence`,
  `hostAwayProvider`, `inProcess`, `HostType.tablet` or `HostIdentity.kind`/`serviceName` anywhere. The plan is written
  against those names as the brief says, and states that slice S1 cannot compile until s5a lands.
- **The pause menu is a root-navigator dialog.** `showDialog` at `pause_menu.dart:110-117` defaults to
  `useRootNavigator: true`, so it is built above any `ProviderScope` inside the host route. The contract's "nested scope
  with party_host's overrides" therefore cannot serve it: the dialog would read the root container, where
  `hostIdentityProvider`/`hostDirectoriesProvider`/`prefsProvider` throw (`party_host/lib/src/providers.dart:27,34,39`)
  and `hostServiceProvider` would build and start a second `LiveHostService` (`:64-76`). Hence the phone puts its four
  party_host inputs in the **root** `ProviderScope` in `main.dart` (as the TV app does, `tv_test_app/lib/main.dart:18-24`)
  and keeps a nested scope for `clientProvider` only. The alternative — one line, `useRootNavigator: false` — is Question 1.
- **`hostServiceProvider` must be a delegating override, not a value.** The phone's host does not exist at app start.
  `hostServiceProvider.overrideWith((ref) => ref.watch(phoneServiceProvider))`, with `phoneServiceProvider` reading
  `hostingProvider`; the stop rule is "keep the last host in the state, dispose it" so that nothing downstream rebuilds with
  nothing behind it, and a second start replaces the state (one deliberate rebuild on the new service). That is
  conflict 2 in the plan and the main risk of the design; Question 1 offers the way out.
- **The seam for the background already exists.** `ControlsLayer` takes a `child` drawn behind the controls
  (`controls_layer.dart:14,21,32`, default `SizedBox.shrink()`); `_Controls` just never passes one (`controller_parts.dart:31`).
  `ControllerScreen` gains `background` and `controls`; `background != null` is the documented meaning of "this app is
  hosting".
- **The own player is a normal controller** (contract §0): the phone's own `ControllerIdentity` (`storage.dart:16-42`),
  `ControllerClient` over `InProcessConnector` (`transport/in_process_connector.dart:11-21`), the pairing code from
  `service.state.host.pairingCode` (`host_service.dart:173-186`, `host_server.dart:105-108`), and a **placeholder hostId**
  in `HostAddress.local` that the welcome overwrites before anything is saved (`client_messages.dart:116,141-143`), with no
  `onTokenChanged` and no tokens, so nothing is persisted for it — the same shape as the TV's simulated controllers
  (`simulated_controllers.dart:46-79`).
- **What must not run in host mode** (each with the line that does it today): reconnect/`openConnect` (`:44`), the session
  monitor (`:47`), `discovery.restart()` on resume (`:62`), the `clientState`→discovery listener (`:105-109`), and the
  `discoveryState`→`updateAddress` listener (`:111-116`) — that last watch is what *creates* the discovery provider
  (`providers/connection.dart:12-17`, which starts Bonsoir browsing for the app's life), so dropping it in host mode means
  Bonsoir is never built by that path, and `HostingNotifier.start` also calls `discovery.stop()`
  (`discovery.dart:111`). The rating prompt (`controller_screen.dart:92-94`) is skipped too (Question 5). Everything else —
  the saved pad mode, gyro/haptics, `client.resume()`, `padProvider.releaseAll()`, the game layout, tv haptics, outages —
  stays.
- **The host screen must watch `party.gameSoundsProvider` and `party.keepAwakeProvider`**, exactly as the TV's home screen
  does (`home_screen.dart:28-30`): nothing else on the phone keeps a hosted game audible or the screen awake.
- **The games screen goes in a nested `Navigator`** whose initial route is named `gamesRouteName`
  (`games_screen.dart:14`). That is what makes `leaveForGamePicker`'s `popUntil` (`pause_menu.dart:129-131`) land on the
  game picker inside the body, and what keeps the bar and the controls on top of a pushed Shape Race. `ControllerMenus`
  (the A/B/D-pad driver, `controller_menus.dart:73-249`) wraps the host screen as it wraps the TV's `MaterialApp`
  (`tv_test_app/lib/main.dart:41`); the party_host screens' `Focus(autofocus: true)` (`join_screen.dart:250-251`,
  `puzzle_screen.dart:136-137`) and Escape shortcuts (`games_screen.dart:25-26`) are inert on a phone but harmless.
- **The entry**: the Connect screen gains "Host a game" beside "Try without a TV" (`connect_screen.dart:241-249`, and again
  in the failed branch `:299-307`), opening a two-choice sheet whose phone option is the default. The file is 412 today
  (over the 400 hard limit), so `ConnectionPanel` + `_CodeEntry` move out first and the file lands near 225.
- **Dependencies**: only `party_host` and `path_provider` (already `^2.1.6` in the TV app, `tv_test_app/pubspec.yaml:31`)
  are imported; the contract's other three libraries arrive through `party_host` and their assets bundle through it
  (Question 3). No Android permission is needed: the phone already declares `INTERNET`, `ACCESS_NETWORK_STATE` and
  `CHANGE_WIFI_MULTICAST_STATE` (`AndroidManifest.xml:2-6`, with the file's own note that Android 12+ needs no runtime
  permission for NSD), and `VIBRATE` (`:8`); `NEARBY_WIFI_DEVICES` is a Wi-Fi scan/Aware/RTT permission, not `NsdManager`;
  `WAKE_LOCK` comes from `wakelock_plus`'s manifest merge the same way it does for the TV app. iOS 26.0
  (`project.pbxproj:363,490,542`) and `minSdk 31` (`build.gradle.kts:35`) already cover every new plugin, and
  `NSLocalNetworkUsageDescription` + `NSBonjourServices = [_gamectl._tcp]` (`Info.plist:29-34`) already cover advertising
  `serviceType` (`protocol/lib/src/network.dart:6`). Advertising from a phone is unproven (contract §0 Q7) and is the one
  real unknown.

## Computed values (for G3 and the planned tests)

- Test window: **852×393** logical (`pump_app.dart:46`) — width 852 ≥ `minWindowWidth` 540 (`layout.dart:37`).
- Top bar: `Padding.fromLTRB(12,4,8,0)` (`controller_top_bar.dart:23`) over a `Row` whose tallest child is an
  `IconButton` (48) → **52**. Body = 393 − 52 = **341** ≥ `minBodyHeight` 250 (`layout.dart:40`). So the games screen and
  `ControlsLayer` are both **852×341** in the test (the equality is an assertion in G3).
- Games screen inside 341: its `AppBar` is 56, the `ListView` pads 24 → the picker band is 24..261 high inside the body,
  285 tall; the two 380-wide cards fit one run: 380+24+380 = **784** ≤ 852−2×24 = 804.
- D-pad/face squares at `pxPerMm` 160/25.4 = 6.2992, `boxHeight = min(341, 58×6.2992=365.4) = 341`:
  `leftArea = (24,8)-(343,325)`, `rightArea = (509,8)-(828,325)`; `square()` side = min(319, 317) = **317**, so the D-pad is
  `(25,8)-(342,325)` (centre 183.5,166.5) and the face buttons `(510,8)-(827,325)` (centre 668.5,166.5).
- A (0.5, 0.81 of the face square) = **(668.5, 264.8)** — the `tapAt` point for `tapFace(tester, ControllerButton.a)`, the
  idiom from `game_controls_test.dart:57-61`.
- The Shape Race card is 380×180 at (24,80)-(404,260) in body coordinates (24 list padding + 56 AppBar), centre
  **(214,170)**; that is **30.7 px** from the D-pad centre, and `dpadDirection`'s dead zone is `0.2 × 159.5` = **31.7 px**
  (`pad.dart:198-207`). Inside by ~1 px — so the G3 test presses A on the pad and never taps the card.
- Select/Start pills: x 378..474; `columnHeight` 160 centred in 341 → Select y 90.5..134.5, Start 150.5..194.5.

## Questions

The nine questions, each with a proposed answer, are in the plan's §13 (summarised one per line below):

1. Root scope overrides vs `useRootNavigator: false` in party_host (the dialog problem). *Proposed: root overrides.*
2. The own player's `hostId` (placeholder vs `HostService.hostId`). *Proposed: placeholder.*
3. The pubspec list (two direct deps vs the contract's five). *Proposed: two.*
4. Where the pairing code is shown on a phone. *Proposed: the host chip's menu.*
5. The rating prompt in host mode. *Proposed: skipped.*
6. Two bars (the app's 52 and party_host's 56 `AppBar`) on a 393-high screen. *Proposed: keep both.*
7. A real `LiveHostService` in the widget test. *Proposed: yes.*
8. Who records `round_end`/`abandoned`, and a `resume()` counter on s5a's `FakeHostService`. *Proposed: s5a records,
   the fake counts.*
9. `ControllerScreen`'s two parameters (`background`/`controls`, with `background != null` = hosting). *Proposed: as named.*

## Suggestions (not acted on)

- s5a could expose `String get hostId` on `HostService` (it has `_hostId` at `host_service.dart:154`) — one line, removes
  the placeholder.
- `connect_screen_test.dart` is a good place for the entry tests and it already exists; the plan extends it rather than
  adding a new file.
- If the "keep the last host" rule ever feels wrong, the alternative is a `hostServiceProvider` that throws on read after
  stop plus an explicit `invalidate` from `HostingNotifier.stop()`; it gives a cleaner graph shape but a stop would rebuild
  every party_host widget, which is why I did not choose it.

## Checks

No analyzers or tests apply to a docs-only job. What I ran:

- `git status --short` — only `docs/briefs/m12/s5b-g1-plan.md` and `docs/briefs/m12/s5b-g1-report.md` are new from me
  (the other entries predate the job; `tv_test_app/windows/flutter/generated_*` are the known flaky generated files).
  `packages/` is clean, which is the s5a evidence.
- `grep`/`sed` read-backs of every `file:line` cited in the plan (the corrections listed in "What I did"); all now match.
- `wc -l docs/briefs/m12/s5b-g1-plan.md` → 582 lines (a plan, not code; no 300-line rule applies to it).
- Re-derived the layout arithmetic above from `layout.dart:176-206`, `layout.dart:30-31`, `pad.dart:198-207` and
  `pump_app.dart:46` rather than trusting earlier notes.

## Commit message

Plan host mode in the phone app (s5b G1)

Plans the phone side of M12 host mode: "Host a game" on the Connect
screen, a PhoneHost (identity, directories, in-process listener, own
player, presence) and the host screen with the games screen as the
controls layer's child, so the phone plays or just shows the game.
Puts party_host's overrides in the root scope: the pause menu is a
root-navigator dialog. Spells out the switch-offs, the own player's
in-process pairing, the G3 widget test and the open questions.

## Status row

Step 5b G1 plan done ([s5b-g1-plan.md](s5b-g1-plan.md)): the full s5b plan with file sizes, the scope decision, the own player, the switch-offs and the G3/G4 tests; open: Claude's answers to its 9 questions, then G3 after s5a lands.

## Delete

- none
