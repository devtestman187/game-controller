job: m12 step5 s5b G1 — plan for host mode in the phone app
stop: after G1. A plan only: no code, no file changes except the plan.
read: docs/design/m12-host-mode.md (the contract; it wins) · docs/briefs/m12/s5-g0-survey.md (facts) · docs/briefs/m12/s5a.md (the host side, running now: `HostService.resume`, `HostPresence`, `hostAwayProvider`, `HostIdentity.kind`/`serviceName`, `LiveHostService(inProcess:)`, `HostType.tablet`; plan against those names) · docs/coding-guidelines.md · controller_app (lib, test, pubspec.yaml, ios/Runner/Info.plist, android/app/src/main/AndroidManifest.xml, android/app/build.gradle.kts) · packages/party_host/lib (providers.dart, host_service.dart, ui/games_screen.dart, ui/pause_menu.dart, testing/host_fakes.dart) · packages/connection/lib/src/transport · tv_test_app/lib (main.dart, src/tv_host_setup.dart: how the TV builds and scopes the host)

the job the plan is for (s5b G3 then G4): m12-host-mode.md §3. In short:
- "Host a game" on `ConnectScreen` → a start sheet: "Play on this phone" (default) or "Show on this device" (C34).
- `PhoneHost` (`lib/src/host/`): the phone's `HostIdentity` (kind `phone`/`tablet` from `DeviceInfo.kind`, `serviceName` "Thumb Party on <controller name>", `hostType` the same), `PhoneHostDirectories`, an `InProcessListener`, prefs and log; it starts the `LiveHostService` and owns `HostPresence` through an `AppLifecycleListener`.
- The host screen: a nested `ProviderScope` with party_host's overrides; the party_host games screen as `ControlsLayer`'s child (`ControllerScreen` gains a `background` widget), the own player's `ControllerClient` over `InProcessConnector` as `clientProvider`, no reconnect and no `ConnectScreen` in host mode, `gameShownProvider` true. "Show on this device": the games screen alone, no own player.
- "Stop hosting" disposes the host and returns to `ConnectScreen`.
- `_TopBar.build` (`controller_top_bar.dart`, 129 lines) splits under 60 lines in this job, since host mode changes the bar.

the plan must answer, with file:line facts:
- every file touched or created, its size now and after, the order; anything over 300 after and how it splits.
- the provider scoping: which party_host providers the TV overrides and how (`tv_test_app/lib/main.dart`), which the phone must override, the name clashes (`prefsProvider`, `logProvider`, `logLinesProvider`) and how imports avoid them.
- how the own player pairs: where the host's pairing code is read, how the TV's simulated controllers pair (file:line), and the identity the own player sends.
- what `ControllerScreen`, its top bar and its providers do on start that must not run in host mode (reconnect, discovery, `ConnectScreen`, session monitor), and how host mode switches each off.
- how the party_host games screen fits as the layer's child: its size (the body box below the top bar), its focus and keyboard handlers (they're TV-shaped; anything that breaks on a phone), the pause menu's Quit route (`gamesRouteName`) inside a nested navigator.
- pubspec: the new dependencies, and anything they need in the iOS/Android projects (flutter_soloud, bonsoir advertising permissions on Android 12+ such as `NEARBY_WIFI_DEVICES` if any, iOS keys). Say what you're sure of and what is unsure.
- the G3 slice: one path through, end to end, as a widget test: "Host a game" → "Play on this phone" → the games screen behind the controls with the own player paired (on the in-process link only) → Shape Race solo starts. Which fakes it needs.
- the G4 rest, and its tests (contract §4).
- conflicts with the contract or with s5a, and questions (numbered), each with your proposed answer.

rules: read-only except the plan file. Facts with file:line. Don't paste code longer than 5 lines.
allow: docs/briefs/m12/s5b-g1-plan.md
report: docs/briefs/m12/s5b-g1-report.md
