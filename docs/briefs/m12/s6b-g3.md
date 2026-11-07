job: m12 step6 s6b G3 — the joined view on the phone, first slice
stop: after G3 (the slice below with its tests passing). Do nothing from the G4 list.
read: docs/design/m12-joined-view.md (contract: §0, §5) · docs/design/m12-phone-layout.md §0.7 · docs/briefs/m12/s6-g0-survey.md · docs/briefs/m12/s6a-report.md · docs/coding-guidelines.md · controller_app/lib (storage.dart, providers/{connection,game_feedback,device}.dart, ui/{controller_screen,controller_parts,controls_layer,bar_connection}.dart, host/{host_screen,hosting}.dart) · controller_app/pubspec.yaml · controller_app/test/support · packages/game_kit/lib/src/frame_view.dart · packages/connection/lib/src/{client_controls,viewer_stats}.dart

G3 slice:
1 pubspec: `game_kit`, `puzzle_game`, `test_game` as direct dependencies (`pub: yes`).
2 storage.dart: the identity lists `Capability.view`. The host's own player must not: `host/hosting.dart` (`controller: ref.read(identityProvider)`) pairs it with the identity minus `view` (s6a answer: the server has no rule for it). Test it.
3 `gameRegistryProvider` = `GameRegistry([shapeRaceModule, arenaModule])`.
4 `viewActiveProvider`: true from a `ViewStarted` on `clientProvider`'s `view` stream until a `ViewEnded`, or until the client changes (a new client starts false). `showsGameProvider` = `gameShownProvider` || `viewActiveProvider`; the controls' opacity (`controller_parts.dart:32`) and the status panel (`bar_connection.dart`) read it instead of `gameShownProvider`.
5 `ui/joined_view.dart` `JoinedView`: `FrameView(views: client.view, registry, stats: client.viewerStats!, nowMs: client.nowMs, playerId: identity.controllerId, onSounds: names → party sound player .play each)`; shown only while `viewActiveProvider` is true (else nothing). `ControllerScreen` uses it as the background when none is given (the host route keeps passing `HostGames`).
6 The shown game fills the whole safe area behind the top bar; the bar's background is transparent while `showsGameProvider` is true; the controls and the touch metrics keep the body box below the bar (contract §5). Applies to `HostGames` too.
7 Test support: `FakeClient` gets a `view` stream (a controller the test adds to), a real `ViewerStats`, and `nowMs`.

G3 tests (controller_app):
- the identity sent in the hello lists `view`; the host's own player's identity doesn't.
- a fake client's `ViewStarted` (Arena, `arenaModule`'s id and snapshot version) then a frame → the Arena's widget is found behind the controls, the controls take the saved opacity (`controlsOpacity` 0.6 → the layer's opacity), the status panel is hidden; a `ViewEnded` → the Arena is gone, opacity back to full, panel back.
- an unknown module in `ViewStarted` → `updateAppText` shown.
- frames carrying sounds → the fake sound player (party_host's `FakeSoundPlayer`) plays each name once.
- the game's box is the full safe area (the background's size equals the screen minus safe insets) while the controls' touch map still uses the body below the bar (one assertion each), at 852×393.
- a new client (TV client replaced) → `viewActiveProvider` false.
- existing tests: the host route still shows `HostGames` behind the controls; no expected value changes (list any old → new).

G4 list (NOT in this job; for your plan only): the waiting card and countdown (contract §0.3), the abandoned notice (§0.5), host list labels (§0.6), `service.shareView` from the start sheet (§0.1), the sound player restart on app show for the joined view, the Diagnostics "Game view" section.

report: line counts of files touched (flag > 300), test counts per check before and after, how `viewActiveProvider` follows a client change, and a plan for the G4 list (files, order, risks) in at most 20 lines.
rules: no lib file over 400 (tests 500); every party_host import is `as party`; `diagnostics_screen.dart` untouched in G3; `controller_client.dart` untouched · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s6b-g3-report.md · controller_app/lib · controller_app/test · controller_app/pubspec.yaml · pubspec.lock
pub: yes
check: format analyze phone
report: docs/briefs/m12/s6b-g3-report.md
