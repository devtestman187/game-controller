job: m12 step5 s5b G3 — host mode in the phone app, first slice
stop: after G3 = plan slices S0 and S1 (plan §11 files 1–20, with host_mode_test's first case only). No C34, no Stop hosting, no lifecycle tests yet (G4).
read: docs/briefs/m12/s5b-g1-plan.md (the plan; with the decisions below it is the job) · docs/design/m12-host-mode.md (the contract; it wins where the decisions don't say otherwise) · docs/coding-guidelines.md · the files in plan §11 as they are now

since the plan was written: s5a landed (`f42d305`). Re-read `party_host/lib/src/{host_service,host_identity,host_presence,host_advertising,lan_listener}.dart` and `testing/host_fakes.dart` (`FakeHostService.resumes` counts `resume()` calls). Its names are as the plan expects: `LiveHostService(inProcess:)`, `HostIdentity.kind`/`serviceName`, `HostKind`, `HostType.tablet`, `HostPresence`, `hostAwayProvider`, `abandonRound`.

decisions (answers to plan §13):
- Q1 Root overrides, as written (plan §1). The nested `ProviderScope` only overrides `clientProvider`.
- Q2 The own player's `hostId` is a placeholder (the phone's own controller id); the welcome replaces it.
- Q3 `party_host` and `path_provider` only.
- Q4 The host chip in the top bar ("Hosting · 0427") with the code, the first address, "New code" and "Stop hosting" (Stop hosting is G4; the chip shows the code in G3). In "Show on this device" (G4) the chip stays, so the code is always on screen.
- Q5 No rating prompt in host mode.
- Q6 Keep both bars for now; step 7 decides the phone's look.
- Q7 Yes: the real `LiveHostService` in the widget test, with `FakeAdvertiser`, `FakeSoundPlayer`, `FakeScreenAwake`.
- Q8 G4 records abandonment (the game packages are allowed then). In G3, `PhoneHost` passes `onAbandon` that pops the games navigator to `gamesRouteName`.
- Q9 `background`/`controls` as named; `background != null` means "this app is hosting", documented on `ControllerScreen`.

do: plan slices S0 and S1 in plan §11's order. S0 is moves first (connect_screen split, top bar split): prove them with `tools/review.sh --strings` and unchanged test counts before S1. `_TopBar.build` ends under 60 lines.
tests: plan §9 (the G3 path, steps 1–6). Existing tests: no expected value changes; list any old → new with the reason.
report: line counts of every file touched or created (flag > 300), the `--strings` proof of the S0 moves, test counts per check before and after, and anything from plan §8's "Unsure" you found out.
rules: no lib file over 400 (tests 500); new lib files ≤ 300; every `package:party_host/party_host.dart` import in controller_app is `as party`; no change outside controller_app; the TV app and its tests unchanged · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s5b-g3-report.md · controller_app/lib · controller_app/test · controller_app/pubspec.yaml · pubspec.lock
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s5b-g3-report.md
