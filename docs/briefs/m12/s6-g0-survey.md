# M12 step 6 G0 survey — the joined view

Read-only survey; the only file changed is this report (`docs/briefs/m12/s6-g0-survey.md`). Facts read from the code
unless marked **unsure** (inferred or not measured). No test values were computed: this gate changes no code.
`git status` also shows `tv_test_app/windows/flutter/generated_plugin*` modified; this job touched no file but this report
**unsure** whether those were already dirty when the job started (generated files, never edited here).

## Answers

**1. Capabilities.** The phone lists `metrics, rating, layout, status` — not `view` (`controller_app/lib/src/storage.dart:34`, identity built `:29-41`). They are a field of `ControllerIdentity` (`packages/connection/lib/src/controller_identity.dart:20`), sent in the hello (`:34-41`). The client makes a `ClientViewer` only when the list has `view` (`controller_client.dart:44`) and drops view messages otherwise (`client_messages.dart:83`). The host maps view messages to the capability (`host_server.dart:229-241`) and sends them only to controllers that listed it (`:196-215`). The host's own in-process player is built from the app's own identity (`controller_app/lib/src/host/hosting.dart:54-61` `controller: ref.read(identityProvider)`, `host/phone_host.dart:47-51`, `providers/device.dart:37-42`), so today it lists no `view` and gets no frames. **If step 6 adds `view` there, the own player lists it too:** `hasViewers` is then always true while hosting (`server_game_host.dart:194`), the host publishes a frame every interval to itself (`:206-210`), and a viewer that pairs mid-game gets start + latest frame (`:275-281`). Nothing special-cases the own player (conflict 1).

**2. `FrameView`** (`packages/game_kit/lib/src/frame_view.dart:33-68`): `views` (`Stream<ViewEvent>`, the client's), `registry` (`GameRegistry`), `stats` (`ViewerStats`, the client's), `nowMs` (the client's clock), `playerId` (optional), `settings` (`HostingSettings.defaults`). Before a start it draws `SizedBox.shrink()` (`:211-213`); an unknown module, a snapshot-version mismatch or a `FormatException` from `createViewer` shows `updateAppText` centred (`:15`, `:120-143`, `:211`), and a frame that doesn't decode is dropped (`:153-160`). The puzzle viewer also shows `updateAppText` when its files lack the puzzle ID (`puzzle_module.dart:96-111`). Draw time: the tick that picks a new `a` schedules a post-frame callback (`:194-197`) that calls `stats.frameDrawn(acks[playerId], nowMs())` once per frame (`:202-206`); jitter goes in on arrival (`:151-152`); `stats.reset(hz:)` on a start it can show (`:135`). `ViewContext` is built from the drawn frame's roster plus `playerId` (`:216`). **No `LocalEcho` hook exists**: `GameModule` has `id`, `snapshotVersion`, `createViewer` only (`game_module.dart:6-17`), `FrameView` has no such parameter, and the name appears only in `m12.md:80,146`.

**3. The client's `view` stream.** Sealed `ViewEvent`: `ViewStarted(ViewStartMessage)`, `ViewFrame(FrameMessage, arrivedAtMs)`, `ViewEnded(ViewEndMessage)` (`client_controls.dart:104-131`); `ControllerClient.view` (`controller_client.dart:138`). Produced in `ClientMessages.onData` (`client_messages.dart:67-75`) → `ClientControls.addViewStart/addViewFrame/addViewEnd` (`client_controls.dart:68-83`), `arrivedAtMs` taken on the client's clock (`:72`). The stream belongs to the client for its whole life, so it survives reconnects (`client_controls.dart:9-11`). On a (re)join the **server** re-sends: `ServerGameHost._checkPlayers` → `_sendView` sends the kept `view_start`, then the latest frame (`server_game_host.dart:258-281`); `endView` forgets both (`:212-217`). Known caveat (STATUS, s3a): a viewer may get one frame before `view_start`; `FrameView` ignores frames until a start.

**4. `gameShownProvider` and `ControlsLayer`.** Defined `controller_app/lib/src/providers/game_feedback.dart:37`, a bare bool with `set()` (`:41-46`); set true by the host route (`host/hosting.dart:26`) and false when it stops (`:45`). Read by the controls for the opacity (`ui/controller_parts.dart:32-34`) and by the top bar to hide the status panel (`ui/bar_connection.dart:24,47-49`). The controls draw over a child in `ui/controller_parts.dart:38-44` → `ControlsLayer(opacity, child:)` (`ui/controls_layer.dart:13-44`, `Stack` at `:30-42`); the child is `ControllerScreen.background` (`ui/controller_screen.dart:32-38`, `:175-176`), which the host route passes as `HostGames` (`host/host_screen.dart:66-70`). A joined phone's `ControllerScreen` (the app's home, `main.dart:42`) passes no background today, so `FrameView` would go in as `background:` — or a sibling in `_Controls` — and `gameShownProvider` must be set by whatever starts the view.

**5. Waiting for host.** Nothing goes on the wire when the host pauses: `Pausable` returns `paused: true` while away (`pause_menu.dart:86-89`, `:133-139`), the view hands it to `session.paused` (`game_session.dart:154-164`) and `advance` returns before stepping or publishing (`:171-175`). No message type or call exists for pause; only `view_end`/`view_start` are wired (`game_session.dart:30-38`, `:211-225`). So during the 30 s a joined phone keeps drawing its newest frame forever (`frame_view.dart:182-217`; pinned as "never runs past the newest", `game_kit/test/frame_view_test.dart:132-143`) with no countdown and no "Waiting for host" text anywhere (grep: only `m12.md:105,146`; `hostGraceS` is `host/phone_host.dart:24`). After the abandon the phone gets `view_end` `abandoned` (`game_session.dart:221-225`) and `FrameView` clears to nothing (`:164-174`) — a blank screen with no reason shown. The round is recorded `abandoned` (`puzzle_session.dart:161-165`, `arena_session.dart:108-115`).

**6. Sounds on a viewer.** Frames carry `snd` (built in `game_session.dart:108-113`, `:257-275`). On the host, sounds play through `GameHost.playSound` → `sounds` stream (`server_game_host.dart:69-78`) → `party_host`'s `gameSoundsProvider` (`providers.dart:119-123`) and `soundPlayerProvider` (`:156-161`, `SoLoudSoundPlayer` in `sound.dart:30-166`); in the phone app only the host route keeps them alive (`host/host_screen.dart:43,56`). `FrameView` ignores `frame.sounds` entirely — no player parameter, nothing in `_addFrame`/`_tick`. Assets: `game_assets` (`assets/pubspec.yaml:24-25`, `assets/lib/asset_manifest.dart:16-60`, ten `.ogg` files in `assets/audio/`). `controller_app/pubspec.yaml:13-31` lists no `game_assets` and no `flutter_soloud`; both arrive only through `party_host`.

**7. Games on the phone.** `controller_app/pubspec.yaml:13-31` has `connection`, `metrics`, `party_host`, `protocol` — **no `game_kit`, `puzzle_game`, `test_game` or `game_assets`** (m12-host-mode.md §3 says it should). The modules are exported by the games (`puzzle_game/lib/src/puzzle_module.dart:48-49` `shapeRaceModule`, `test_game/lib/src/arena_module.dart`), and the registry is built by the app: `GameRegistry([shapeRaceModule, arenaModule])` (`game_registry.dart:8-22`); nothing in `lib/` builds one today. The puzzle viewer finds its puzzle by ID itself: a shared lazy `PuzzleLibrary.load()` (`puzzle_module.dart:88-111`) reading `packages/puzzle_game/puzzles/index.json` (`library.dart:15-23`), which is bundled from `puzzle_game`'s own assets (`puzzle_game/pubspec.yaml`, `flutter: assets: - puzzles/`) — so the phone needs no file from the host, but does need `puzzle_game` as a direct dependency (for the import).

**8. Host list labels (C26).** The host writes `kind` in the TXT record (`party_host/lib/src/host_advertising.dart:22`, `HostKind` `host_identity.dart:3-12`). The phone reads only `id` and `v` (`controller_app/lib/src/discovery.dart:165-180`); `DiscoveredHost` has no kind (`:8-19`); the list shows every host with `Icon(Icons.tv)` and the mDNS name (`ui/connect_screen.dart:105-120`, icon `:108`, title `:109`, subtitle `:110-114`), under the heading "TVs on this Wi-Fi" (`:92`). No phone/tablet/TV icon or label exists anywhere in the app (grep `kind` in `controller_app/lib`: none).

**9. Metrics.** The phone's batches (`phone_metrics.dart:123-137`) carry only segment data; the viewer's samples are added on the one send path, `ControllerClient.sendMetrics` (`controller_client.dart:153-163`) via `ClientViewer.withSamples` (`client_viewer.dart:30-42`) from `ViewerStats.drain` (`viewer_stats.dart:111-126`), giving the batch's `stages` and `view`. Batches are sent only while `PhoneMetrics` is active (connected, not demo, "share stats" on: `providers/metrics.dart:72-75`), so without a batch the samples wait. On the host every sample becomes `reportStage` (`server_game_host.dart:25`, `:224-239`) → the host's `stages` stream → `LiveStats` → `SessionCollector.stage` (`live_stats.dart:59`, `metrics/lib/src/session.dart:155-159`), which is **per player**: the round summary writes each player's `stages` and the `view` counts (`session.dart:276-278`), and the report reads them (`report.dart:203-238`).

**10. Existing viewer fakes.** `game_kit`: `test/support/fake_view.dart:5-73` (`DotModule`, `DotSnapshot` v3, `DotDraw`), driven in `frame_view_test.dart` by a plain `StreamController<ViewEvent>` (`:40`) with `startEvent`/`frameEvent` helpers (`:20-37`) — `FrameView` takes a stream, not a client, so a widget test needs no host. `connection`: `test/helpers.dart:32-80` (`startHost(capabilities:)`, `newClient(capabilities:)`), `test/fake_host.dart:18-59` (`FakeHost.start` + scripted `onChannel`), `test/wire_phone.dart:16-81` (a raw phone), pinned by `view_test.dart:40-42` and `client_view_test.dart:11-12`; `MemoryGameHost.viewStarts/frames/viewEnds` (`memory_game_host.dart:35-42`) hold what a session sent. `controller_app`: `test/support/fakes.dart:12` `FakeClient` overrides the haptics, layout, status, rating and metrics streams but **not `view`/`viewerStats`**, so it can't feed a start or a frame today; `pump_app.dart:82-111` overrides `tvClientProvider` and friends, `host_app.dart:30-53` the `party_host` fakes for the host route.

## Sizes

| File | Lines |
| --- | --- |
| `controller_app/pubspec.yaml` / `lib/src/storage.dart` / `lib/src/discovery.dart` | 38 / 107 / 191 |
| `controller_app/lib/src/ui/connect_screen.dart` / `ui/connect_panels.dart` | 226 / 298 |
| `controller_app/lib/src/ui/controller_screen.dart` / `ui/controller_parts.dart` / `ui/controls_layer.dart` | 188 / 125 / 44 |
| `controller_app/lib/src/ui/bar_connection.dart` / `ui/diagnostics_screen.dart` | 93 / 355 ⚑ |
| `controller_app/lib/src/providers/game_feedback.dart` / `providers/connection.dart` / `providers/device.dart` | 96 / 206 / 79 |
| `controller_app/lib/src/phone_metrics.dart` / `lib/src/host/hosting.dart` / `host/host_screen.dart` | 239 / 74 / 73 |
| `controller_app/test/support/fakes.dart` / `pump_app.dart` / `host_app.dart` | 218 / 147 / 157 |
| `controller_app/test/connect_screen_test.dart` / `host_mode_test.dart` / `hosting_test.dart` | 143 / 162 / 100 |
| new `controller_app/lib/src/providers/view.dart`, `lib/src/ui/*view*` (FrameView, waiting, sounds) | new |
| new `controller_app/test/view*_test.dart` | new |
| `game_kit/lib/src/frame_view.dart` / `game_module.dart` / `game_registry.dart` | 218 / 44 / 22 |
| `connection/lib/src/controller_client.dart` / `client_controls.dart` / `server_game_host.dart` | 398 ⚑ (400 hard limit; next addition splits it) / 131 / 297 |
| `connection/lib/src/viewer_stats.dart` / `viewer_timing.dart` / `client_viewer.dart` | 149 / 154 / 43 |
| `party_host/lib/src/providers.dart` / `host_service.dart` / `sound.dart` | 280 / 329 ⚑ / 166 |
| `party_host/lib/src/host_presence.dart` / `abandon_signal.dart` | 98 / 17 |
| `puzzle_game/lib/src/puzzle_module.dart` / `test_game/lib/src/arena_module.dart` | 112 / 44 |
| `game_kit/test/frame_view_test.dart` / `connection/test/view_test.dart` / `client_view_test.dart` | 264 / 417 / 161 |

⚑ over 300.

## Constraints

- Exported API: `connection.dart:8-36` (`ControllerClient` incl. `view`, `viewerStats`, `nowMs`; `ViewEvent`s; `ViewerStats`; `ViewerTiming`), `game_kit.dart:6-10` (`FrameView`, `GameModule`, `GameRegistry`, `GameSession`, `HostingSettings`), `party_host.dart` (providers incl. `soundPlayerProvider`), `puzzle_game.dart` / `test_game.dart` (the modules).
- Wire/persisted: nothing new is needed for step 6 — `view_start`/`frame`/`view_end` and the metrics `stages`/`view` fields exist (`protocol/lib/src/view.dart:8-147`, `metrics.dart`), protocol version stays 1 (`version.dart`); TXT `kind` is already written. Prefs keys the app already owns: `controllerId`, `pairingTokens`, `lastHost`, `controlsOpacity`, `shareStats`.
- Tests that pin behaviour: `frame_view_test.dart` (9 tests), `connection/test/view_test.dart` (late joiner, `sendToAll` capability), `client_view_test.dart` (stages in batches), `puzzle_game`'s module tests; `controller_app` `layout_test.dart` / `controls_layer_test.dart` pin the opacity and `gameShownProvider`; `connect_screen_test.dart` pins the host list and "Host a game".
- `FrameView` needs the client's own **ID** (`identity.controllerId`), not `snapshot.player` (a number), because `acks`/`pl` are keyed by controller ID (`game_session.dart:272`, `server_game_host.dart:124-139`).
- The client's `viewerStats` is null without the capability (`controller_client.dart:142`), so listing `view` is a precondition for `FrameView`'s `stats`.
- `game_kit`'s only test-only game dependency is `test_game` (dev), so a `LocalEcho` added to `GameModule` touches `DotModule` in `test/support/fake_view.dart` and both real modules.

## Conflicts

1. §2.10 (m12.md:105) wants "Waiting for host" with a 30 s countdown on joined phones and, on resume, the host re-sends `view_start` and the latest frame. Nothing is sent on pause or resume today (answer 5); the only re-send is the mid-game pairing path (answer 3), which needs the player list to change.
2. §2.5 (m12.md:80) says step 6's `FrameView` "keeps this possible: a module may supply a `LocalEcho`". No such member exists in `game_kit` (answer 2); adding it changes `GameModule` and every module/test.
3. §2.3 (m12.md:58) has every phone, the host included, play frames' sounds. `FrameView` has no sound path and the phone app has no sound player outside the host route (answer 6); who plays a frame's `snd` when the same frame is drawn twice (a replayed/again-drawn `a`) is undecided. **Unsure:** whether the intended owner is `FrameView` (a `SoundPlayer` parameter) or a provider watching the same stream.
4. §2.4/m12-sessions §1 say the phone lists `view` "only with the test option of §6 until step 6"; that test option was dropped (m12-sessions.md:184), so the phone lists it never today — step 6 is the first place it appears (answer 1).
5. m12-host-mode.md:58 and m12-sessions §5 state `controller_app` depends on `game_kit, puzzle_game, test_game, game_assets`; its pubspec has none of them (answer 7), so the viewer can't import the games or build a registry without that change.
6. S9/§2.7's "while a game is shown the status panel is hidden" relies on `gameShownProvider`, whose only writer is the host route (answer 4); a joined view has no writer and the provider's doc says "a joined phone's own view is step 6's turn" (`game_feedback.dart:39-40`).
7. §2.9/C26: the host already advertises `kind`, but the phone's discovery model and list ignore it (answer 8) — the design's intent, but the work is entirely on the phone side.

## Questions

1. Does the host phone's own player list `view` (so it draws its own game through a `FrameView` and measures)? If not, how is it kept out while other phones list it (`loadIdentity` is shared)?
2. Who plays a frame's `snd` on a joined phone — `FrameView`, or a separate provider on `client.view` — and may it play through `party_host`'s `soundPlayerProvider` (SoLoud) outside host mode?
3. Is "Waiting for host" driven purely from the client side (no frames for N ms → overlay with a countdown) or does the host learn to send something on pause/resume?
4. Is `LocalEcho` part of step 6's API now (in `GameModule`), or only the hook shape Claude wants reserved?
5. Should the viewer's own controls keep working (inputs sent) while the host is away, and what does the phone show when the view ends `abandoned`?
6. Which label set should the host list use for C26 (icon per `kind`, or a text label as well), and what does an older host without `kind` show?

## Commit message

m12 s6-G0: survey the joined phone view

Read docs/design/m12.md §2.3-2.5, §2.9, §2.10 and §5 step 6, m12-sessions, m12-host-mode and the
code they name, then wrote the facts step 6's contract needs: capabilities, FrameView, the client's
view stream and rejoin path, where the controls layer can take a viewer, what a joined phone sees
while the host is away, sounds, the games and registry on the phone, host list labels and metrics.

Findings: the phone lists no view capability; no LocalEcho hook or sound path exists in FrameView;
nothing is sent to viewers on pause; controller_app lacks game_kit, puzzle_game, test_game and
game_assets; discovery ignores the TXT kind. Six open questions for Claude. Read-only: no code changed.

## Status row

| 6 Joined view | G0 survey done ([s6-g0-survey.md](s6-g0-survey.md)): all 10 questions answered with file:line, sizes, constraints, 7 conflicts and 6 questions. Open: Claude's contract (G1/G2) — whether the own player lists `view`, who plays frame sounds, how "Waiting for host" is driven, the `LocalEcho` shape, and adding `game_kit`/`puzzle_game`/`test_game`/`game_assets` to `controller_app` |

## Delete

- none
