# M12 step 3 G0 survey — sessions, frames, playout, stages

Read-only survey; files changed: this report only (`docs/briefs/m12/s3-g0-survey.md`). Facts read from the code unless
marked **unsure** (inferred or not measured).

## Answers

**1. Loops.** Rules built in the widget state (`play_view.dart:95-97`, `arena_view.dart:66`); Ticker `createTicker(_tick)` (`:98`, `:67`), started `initState` (`:122`, `:87`), disposed (`:134`, `:91-95`).
`PuzzlePlayView._tick` (`play_view.dart:144`): `dt = (elapsed - _last).inMicroseconds / 1e6` (`:145`), `_last = elapsed` (`:146`), `if (paused) return` (`:147`); then settings reload (`:149`), `host.players` (`:150`), `setLayout` for new players (`:154-161`, drops gone ids), fresh `inputArrivedAtMs` (`:163-170`), frames/late when `dt > 0.025` (`:171-174`), `match.update(dt, gamepads, numbers)` (`:176-180`), per event haptic/sound/record (`:182-184`, `:216-246`), `_report` once at finish (`:185`, `:250-302`), `playSound` (`:186-188`), `setStatus` (`:189-192`), `setState(snapshot)` (`:193`), post-frame `reportStage(receivedToDrawn)` if fresh input and `dt <= 0.1` (`:195-203`).
`ArenaView._tick` (`arena_view.dart:100-167`) same shape: `dt :101`, paused `:103`, late `lateFrameMs = 25 :56`, round_start record `:116-119`, `_game.update` `:131-132`, events `:133-138`, round_end `:139-153`, `setState :154`, stall `stallS = 0.1 :59`, post-frame `:159-167`; `build` also calls `_game.resize(constraints.biggest)` (`:193`).
`dt` is clamped in the **rules**, not the views: `game.dart:315` and `arena.dart:334` both `clamp(0.0, 0.1)`; a long frame silently becomes 0.1 s.

**2. Rule step APIs.** `PuzzleGame.update(double dt, Map<String, GamepadState> inputs, {Map<String, int> numbers}) -> List<PuzzleEvent>` (`game.dart:306-408`; join/leave from the map `:307-312`, clamp `:315`, clock `:316-321`, input read inline `:327`, `:337`, `:354`, `:438`, `:469-480`).
`PuzzleMatch.update(dt, inputs, numbers) -> List<({PuzzleSide side, PuzzleEvent event})>` (`match.dart:148-165`), `_decide` `:167-193`, `snapshot()` `:196`.
`ArenaGame.update(double dt, Map<String, GameInput> inputs) -> List<GameEvent>` (`arena.dart:328-359`; join/leave `:329-332`, clamp `:334`, `_updatePlayer :361-402`), `resize(Size)` `:303` called by the view.
Events: `PuzzleEvent(kind, {playerId, data})`, kinds `pickup, snap, wrong, dropReady, tick, timeUp, finished, help` (`game.dart:32-48`); `GameEvent(playerId, HapticEvent event, GameEventCause cause, {intensity, durationMs})` + `toMessage()` (`arena.dart:45-65`).
No clock, no unseeded `Random`, no widget code in the rules: `Random` is injected (`game.dart:150`, seed `match.dart:89`), the arena has none; both import `dart:ui` only (`game.dart:3`, `arena.dart:3`), so they need Flutter (`flutter test`), not the plain Dart VM.

**3. Snapshots.** `PuzzleSnapshot` (`snapshot.dart:47-152`): `puzzleId, timeLeftMs, warning, phase, pieces, players, order, readyTargets, hintTargets, finishTimeMs`; `version = 1` (`:61`, checked `:123`), `maxBytes = 2048` (`:64`), keys `v,pz,t,w,ph,o,pc,cl,pl,rd,hn,ft` (`:95-116`).
`MatchSnapshot` (`snapshot.dart:158-189`): `boards`, `seed`; `version = 1` (`:161`, checked `:183`), keys `v,b,sd`.
`ArenaSnapshot` (`arena.dart:559-651`): `round, roundTimeS, phase, walls, goal, hazards, players, start, winnerId, lastTimeS, breakLeftS, bestTimeS, bestId, playerRadius, hazardRadius`; `version = 1` (`:578`, checked `:624`).
Tests pinning it: `rules_test.dart:501-513` (round trip), `:515-520` (`< 2 KB`, 4 players, boat); `match_test.dart:1015-1038` (round trip, `< 2 KB`), `:1040-1072` (seed/pile order on a split, absent on one board); `arena_view_test.dart:193-208` (round trip, `< 2048`).
**Unsure (estimate):** boat has 6 pieces a board; a 4-player 2-board match encodes to roughly 450-600 bytes, arena far less — no test prints a real length.
Drawable from the snapshot alone? Painters read only the snapshot (`view.dart:205-239`, `arena_view.dart:328-384`) but also need puzzle data by `puzzleId`, layout rebuilt at paint from the seed (`view.dart:87`), `timeLimitS` from live settings (`play_view.dart:339`), and for the arena player colours/numbers from the live list (`arena_view.dart:198`, `:342`, `:386-423`, `_Hud :234-289`).

**4. `GameHost`** (`game_host.dart:13-70`): `nowMs :15`, `players :18`, `playersChanged :21`, `gamepad :24`, `inputArrivedAtMs :28`, `haptic :32`, `askRating :36`, `latency :40`, `stageSummary :43`, `addLocalPlayer :47`, `record :50`, `reportStage :54`, `playSound :59`, `setLayout :64`, `setStatus :69`; `PlayerLatency` record `:73-79`.
Implementations: `ServerGameHost` (`server_game_host.dart:15`, built `host_service.dart:116`; extras `records :60`, `sounds :63`, `stages :111`, `layoutOf :66`, `dispose :226`), `MemoryGameHost` (`memory_game_host.dart:13`), `FakeGameHost` (`party_host/lib/src/testing/host_fakes.dart:95`, testing only).
`LocalPlayer` (`local_player.dart:4-28`) is a host-side input source made by `addLocalPlayer` (`server_game_host.dart:196-202`, `memory_game_host.dart:109-127`), driven via `LocalPlayer.set` (`:17`); `ServerGameHost` ignores its haptic/rating/layout/status (`:75`, `:86`, `:154`, `:160`). Keyboard player: `tv_test_app/lib/src/keyboard_player.dart:56`.
Everything the games do reaches the world through `GameHost`: `haptic` (`play_view.dart:212`, `arena_view.dart:134`), `playSound` (`:187`, `:135`), `record` (`:141-142`, `:97-98`), `setLayout`/`setStatus` (`:157`, `:190`, `:109`). Sound playback itself is in `party_host` (`providers.dart:119-123`, `host_service.dart:243`); the haptic panel plays directly (`providers.dart:193`).

**5. Sounds.** Names are the `SoundKey` enum (`assets/lib/asset_manifest.dart:16-36`, package `game_assets`): `hit, success, error, rumble, snap, wrong, tick, pickup, timeUp('time_up'), help`; name lookup `:35`, files `audio/<event>.ogg` (`:42`), `findSound :51-60`.
Call sites: `arena_view.dart:135` (`e.event.name` -> `hit/success/error/rumble`); `play_view.dart:187` fed from `:220, :223, :227, :234, :240, :242, :244, :284`; `providers.dart:121` (stream -> `SoundPlayer`), `:193` (haptics). `dropReady` has no sound.

**6. Game selection.** Only the picker knows both games: two cards in `games_screen.dart:37-52` (`ShapeRaceScreen :43`, `GameScreen :50`), from `home_screen.dart:220`; no `if (game == ...)` elsewhere, views take no game id.
Arena: `game_screen.dart:114` builds `ArenaView(game: widget.game, host, onEvent, paused)`; no settings (constants `arena.dart:185-222`).
Shape Race: `join_screen.dart:223` builds `PuzzleScreen(choice, teams, keyboard)`; `puzzle_screen.dart:97-105` picks the puzzle (`PuzzleChoice.level` `:21-26`), `:67` makes the `Random()` the trays are seeded from, `:154-163` builds `PuzzlePlayView(host, puzzle, teams, random: _random, match: widget.match, paused, settings: () => puzzleSettingsProvider, onFinished)`; rematch `:123`, change teams `:126`. No layout target yet (D4).
Game-name strings only go into records: `play_view.dart:16`, `:142`, `arena_view.dart:24`, `:98`; `session_recorder.dart:8`, `:50` (`'arena'` fallback when a rating is asked before the name is known).

**7. Input `seq` and clock offsets.** Phone increments `seq` per state and stamps its clock (`client_input.dart:45-60`); the host applies only if paired and `message.seq > input.seq` (`host_connection.dart:252-262`), storing `HostConnection.input` (`:95`, `:256`), `inputAtMs` (`:257`), forwarding (`:261`). So the last applied seq is per connection (= per player), exposed to apps only through `ControllerInfo.input` (`host_types.dart:69`, `host_connection.dart:169`); `GameHost` has no seq, only `inputArrivedAtMs` (`server_game_host.dart:150`).
Games poll `GameHost.gamepad(id)` once a tick (`play_view.dart:176-180`, `arena_view.dart:131-132`); `ServerGameHost.gamepad` (`:138-147`) holds a press for `minPressMs = 50` (`:30`, `:143-146`). `playersChanged` is unused; the views poll `host.players` (`play_view.dart:150`, `arena_view.dart:105`).
Clock offset: `InputLatency` per connection (`host_connection.dart:100`), `offsetMs` (`latency.dart:34`, from `addPong :46-54` on `PongMessage.atMs` `host_connection.dart:247`), `uncertaintyMs :37`, one-way delay `addInput :59-67`; public today only `latencyErrorMs` and the delay summaries (`host_types.dart:77-84`), no offset getter on `ControllerInfo`/`GameHost`.

**8. Protocol.** A message is `final class X extends Message` with `static const String wireType`, `toPayload()`, `static fromPayload(Map<String, Object?>)` (`messages.dart:27-47`, e.g. `:292-314`); small ones live in part files (`messages.dart:3-7`, `input.dart`, `metrics.dart`).
Adding one: class + payload throwing `FormatException` with the field name (helpers `messages.dart:325-353`); decoder in `codec.dart:14-30` (unknown -> null, `:61-62`, so older peers skip it); host->controller capability in `HostServer.capabilityFor` (`host_server.dart:216-222`), enforced by `send`/`sendToAll` (`:196-227`); receive: `HostConnection._handle` (`host_connection.dart:212-238`, unexpected types close) and `ClientMessages.onData` (`client_messages.dart:38-69`, checks `isConnected` and the phone's capability `:59`, `:62`, `:65`); capability string `capabilities.dart:9-27`; a `docs/protocol.md` section (direction summary `:224`).
`Capability.view = 'view'` is declared and reserved (`capabilities.dart:24-26`), mentioned in `DeviceRole` (`:31-33`). Gated host sends today: `metrics_ack`, `rate_ask`, `layout`, `status` (`host_server.dart:216-222`); old-peer test pattern `connection/test/m10_test.dart:63-86`.

**9. Stages and metrics.** `LatencyStage` = `sent_to_received`, `received_to_drawn` (`game_types.dart:56-62`); `StageSample = ({String playerId, String stage, int ms})` (`:65`).
`sent_to_received` from `ControllerMessage.delayMs` (`server_game_host.dart:18-24`, delay `latency.dart:59-67`); `received_to_drawn` post-frame in both views (`play_view.dart:196-203`, `arena_view.dart:159-167`). `reportStage` keeps an `RttWindow` per (player, stage) (`server_game_host.dart:50`, `:189-193`), publishes on `stages` (`:111`), `stageSummary` over 30 s (`:178-181`); `MemoryGameHost` appends to a list (`:97`).
Into the session: `live_stats.dart:59` -> `SessionCollector.stage` (`session.dart:212-216`) -> `DelayStats` (`:10-44`) -> summary `stages` (`:328`) as `{n, median, p95, max}` (`:43`). The report reads only `stages['sent_to_received']` (`report.dart:134`) into `inputMedianMs/inputP95Ms` (`:63-64`, CSV `:75-78`); other stages are saved, never printed.
Batch: `MetricsMessage` (`metrics.dart:16-73`) `seg, i, mode, ms, end, data`; `data` is whitelisted in `sanitizeSegmentData` (`segment.dart:285-338`: `v, start, touches, activeMs, presses, pressMs, pressMaxMs, empty, near, slide, rapid, multi, haptics, settings, sticks, gyro`), unknown keys dropped.

**10. Tests.** No fake Ticker: widget tests drive the real Ticker via the test clock (`tester.pump(Duration)`).
Puzzle `view_test.dart` 7 widget tests, loops at `:149-268` (`MemoryGameHost`, `press()` = 2 x 16 ms `:180-185`); `pause_menu_test.dart:36-41` reads `PuzzlePlayViewState.snapshot` and asserts 63 x 16 ms do not move the clock.
Arena `arena_view_test.dart` 9 widget + 1 plain; loops of 60 x 16 ms (`:41-43`, `:67-69`, `:83-85`), up to 400 pumps (`:107-109`, `:124-126`, `:154-156`); timing-sensitive `:38-54`, `:132-148` (2 s stall must not count), `:150-170` (exactly one `receivedToDrawn`).
Rules with a chosen `dt`: `arena_test.dart:15` `step(g, dt, input)`, 1/60 loops `:198-250`; `rules_test.dart:16-24` (0.016); `match_test.dart:29-33` `drive(..., dt = 0.05)` with computed `closeTo(24)` `:993` and `closeTo(8.4)` `:1010`. Neither 0.1 s clamp has a test. No golden files (`matchesGoldenFile` unused; `view_test.dart:85-147` compares two renders of one run).
Counts: `match_test` 31, `rules_test` 24, `view_test` 7; `arena_test` 20, `arena_view_test` 10; `party_host` `game_screen_test` 6, `puzzle_results_test` 4, `puzzle_screen_test` 2, `pause_menu_test` 2, `games_screen_test` 1, `live_stats_test` 6; `connection` `input_test` 12, `m10_test` 5 x 2 + 1, `m9_test` 14; `protocol` `m9_test` 15; `metrics_test` 38.

**11. Adding `packages/game_kit`.** Build needs: a line in the root workspace (`pubspec.yaml:8-17`); a `pubspec.yaml` with `resolution: workspace`, `environment.sdk ^3.13.0`, `flutter: '>=3.38.0'` (as `packages/party_host/pubspec.yaml:10-14`); an `analysis_options.yaml` copied from a sibling (`include: package:flutter_lints/flutter.yaml`, `formatter: page_width: 120`); a `tools/check.sh` entry in `checks` (`tools/check.sh:20-31`) — `format` already covers `packages`, `analyze` covers the workspace (`:21-22`).
Graph from the pubspecs: `protocol` -> none; `connection` -> protocol; `metrics` -> protocol; `puzzle_game` -> connection, protocol, flutter; `test_game` -> connection, protocol, flutter; `assets` (game_assets) -> flutter; `party_host` -> connection, metrics, protocol, puzzle_game, test_game, game_assets, flutter, riverpod, soloud, bonsoir, shared_preferences, path, wakelock; `controller_app` -> connection, metrics, protocol; `tv_test_app` -> party_host, puzzle_game, test_game, game_assets, metrics, protocol, connection.
So a `game_kit` above the games can be used by `party_host` and the apps; the games can use it only if the registry does not live in it (Conflicts 1).

## Sizes

| File | Lines |
| --- | --- |
| new `packages/game_kit/**` (pubspec, options, module, session, frame, registry, playout, settings) | new |
| `protocol/lib/src/messages.dart` | 353 ⚑ |
| `protocol/lib/src/codec.dart` / `capabilities.dart` | 69 / 116 |
| `connection/lib/src/game_host.dart` / `game_types.dart` / `host_types.dart` | 79 / 85 / 126 |
| `connection/lib/src/server_game_host.dart` / `memory_game_host.dart` | 240 / 128 |
| `connection/lib/src/host_server.dart` / `host_connection.dart` | 367 ⚑ / 377 ⚑ |
| `puzzle_game/lib/src/play_view.dart` / `view.dart` / `match.dart` / `snapshot.dart` | 340 ⚑ / 439 ‡ / 198 / 189 |
| `puzzle_game/lib/src/game.dart` | 732 ‡ |
| `test_game/lib/src/arena_view.dart` / `arena.dart` | 451 ‡ / 695 ‡ |
| `party_host/lib/src/ui/puzzle_screen.dart` / `ui/game_screen.dart` / `providers.dart` | 185 / 267 / 280 |
| `party_host/lib/src/live_stats.dart` / `session_recorder.dart` / `sound.dart` | 299 / 121 / 140 |
| `metrics/lib/src/session.dart` / `segment.dart` / `report.dart` | 424 ‡ / 341 ⚑ / 351 ⚑ |
| `tools/check.sh` / root `pubspec.yaml` | 116 / 25 |

⚑ over 300, ‡ over the 400 hard limit (tests 500).

## Constraints

- Exported API: `connection.dart:8-33` (GameHost, GamePlayer, GameRecord, LatencyStage, StageSample, LocalPlayer, MemoryGameHost, ServerGameHost, HostServer, latency); `puzzle_game.dart:8-17`; `test_game.dart:5-6`.
- Wire: envelope `{v: 1, t: type, ...}` with `protocolVersion = 1` (`version.dart:6`, `codec.dart:32`); new messages additive and capability-gated; each documented in `docs/protocol.md`.
- Persisted: session summary `schema: 1` (`session.dart:388`), saved session JSON, `puzzleSettings` in shared_preferences (`providers.dart:261`), host id/pairings in shared_preferences (`host_service.dart:142`).
- Snapshots are versioned and size-tested (`snapshot.dart:61-64`, `arena.dart:578`); any new field rides in a frame payload.
- Tests pinning step 3: `view_test.dart` (7), `arena_view_test.dart` (10), `pause_menu_test.dart:36`, `puzzle_results_test.dart` (4), `game_screen_test.dart` (6), `games_screen_test.dart` (1), the snapshot round-trip/size tests, and rules tests that assume variable `dt` (`match_test.dart:29`, `arena_test.dart:15`).
- Both game packages are Flutter packages and their rules import `dart:ui`, so a pure-Dart `game_kit` cannot reuse `Offset`; it is a Flutter package (as the design says).

## Conflicts

1. §2.3 puts a `GameRegistry` holding Shape Race and Arena **in `game_kit`**, while §2's diagram puts `game_kit` above the game packages, which must depend on it for `GameModule` — a cycle; only one side can hold the registry.
2. `GameHost` has no frame member (`game_host.dart:13-70`); publishing a frame needs a new member, a `HostServer` capability mapping (`host_server.dart:216-222`) and a "only controllers listing `view`" target list, which no send does today except one-by-one `send`.
3. `GameHost` exposes no input `seq` (answer 7), so a frame's acks cannot be built from the interface as it is; the seq lives in `HostConnection.input`, via `ControllerInfo` on the server only.
4. `ArenaSnapshot` has no player number/colour and the painter/HUD take them from the live list (`arena_view.dart:198`, `:342`, `:234-289`); a frame-drawn arena loses them unless the frame or a `player` message supplies them.
5. `ArenaView.build` calls `_game.resize` (`arena_view.dart:193`); a fixed-step session has no widget box, so the session must own the size or the rules must take it per step.
6. `PuzzleSnapshot` has no time limit; the view takes `timeLimitS` from live settings (`play_view.dart:339`), so only `view_start`'s `setup` (§2.4) can supply it to a viewer.
7. `MatchPainter` rebuilds the split layout at paint from the seed (`view.dart:87`); a rule-free `Interpolator` per snapshot type in `game_kit` needs the snapshot type — same cycle as 1.
8. §3's metrics "new field `stages`": the batch's `data` is whitelisted (`segment.dart:315-337`) and would drop it, `SessionCollector` takes one sample at a time (`session.dart:211-216`), and the report prints only `sent_to_received` (`report.dart:134`).
9. §2.3 has `GameSession` turn events into haptics/sounds/records; today that code plus the puzzle's per-player metrics record and `onFinished` live in the views (`play_view.dart:212-302`, `arena_view.dart:132-153`) and read live settings (`play_view.dart:149`).
10. §2.3 says each phone plays sounds from its own copy, but `HostService.gameSounds` is one stream consumed once (`providers.dart:119-123`, `host_service.dart:243`); sounds are not attached to any snapshot yet.

## Questions

1. Where do the two `GameModule` implementations live — in the game packages (registry moves out of `game_kit`) or beside the registry? Decides conflicts 1 and 7.
2. Should a frame's acks and the viewer's `touch_to_frame` be fed by a new `GameHost` member (e.g. `int? inputSeq`) or by the host's own bookkeeping at publish time?
3. Does the viewer get player numbers/colours in the frame, or from `player`/`hello` as controllers do?
4. Where does a viewer's `timeLimitS` come from: `view_start`'s `setup` or a new snapshot field?
5. Is `stages` a new top-level field on the metrics batch (needs `sanitizeSegmentData` + `SessionCollector` changes) or a key inside `data`?
6. What is the expected `tools/check.sh` name for `game_kit` (e.g. `kit`), and does it need the `report`-style tooling?
