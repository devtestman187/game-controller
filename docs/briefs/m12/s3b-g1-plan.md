# M12 step 3b — G1 plan: sessions, the thin views, the modules

Job: [s3b-g1.md](s3b-g1.md). Contract: [m12-sessions.md](../design/m12-sessions.md) §3, §4 (the game_kit block), §5 —
it wins. Facts: [s3-g0-survey.md](s3-g0-survey.md). Read with them: [coding-guidelines.md](../../coding-guidelines.md).
Line numbers are today's files, before the move. No code in this job.

## 0. Facts that shape the plan

- **s3a has landed**: `GameHost.hasViewers/inputSeq/startView/publishFrame/endView` (`game_host.dart:71-90`),
  `MemoryGameHost` keeps `viewStarts`/`frames`/`viewEnds` with a settable `hasViewers` and `inputSeqs`
  (`memory_game_host.dart:30-40`), `ViewStartMessage`/`FrameMessage` (`protocol/lib/src/view.dart:8-107`).
- **Input once an advance, not once a step.** Both views read `host.players` and `host.gamepad` per tick
  (`arena_view.dart:105,132`, `play_view.dart:150,178`); the 50 ms press hold is only in `ServerGameHost`
  (`server_game_host.dart:30,139-147`), `MemoryGameHost` keeps exactly what a test set (`memory_game_host.dart:65-68`).
- **16 ms test pumps against 1/60 s steps.** 60 pumps are 0.96 s = **57 steps**; three of those 60 advances run no
  step at all (pumps 1, 26 and 51 — one in 25 in the steady state). Real play is one step per 60 Hz frame (§3, §6 R1).
- **Colours are already number-derived** (`game_types.dart:35` → `messages.dart:321`), so §3's roster
  (number and name) draws exactly what the TV draws.
- `arena.dart` (695), `game.dart` (732) and `view.dart` (439) are over 400 and must not grow (brief; survey
  "Sizes"): all new code goes to new files (§2).
- Both views keep their public constructors (`arena_view.dart:44`, `play_view.dart:56`) and their test hooks
  (`ArenaView.game` `:50`, `PuzzlePlayViewState.snapshot` `play_view.dart:108`, `PuzzlePlayViewState.match` `:95`),
  so `party_host`, `tv_test_app` and `controller_app` need no change in s3b.

## 1. `packages/game_kit` — every file

Flutter package, `resolution: workspace`, `sdk ^3.13.0`, `flutter '>=3.38.0'` (as `packages/party_host/pubspec.yaml:10-14`),
depends on `connection` (`../connection`) and `protocol` (`../protocol`); the options file is
`packages/puzzle_game/analysis_options.yaml` verbatim.

| File | Types | Est. lines |
| --- | --- | --- |
| `lib/game_kit.dart` | library doc + exports (module, registry, session, settings) | 15 |
| `lib/src/game_session.dart` | `GameSession` (contract §3) + the loop: accumulator, frames, `drawn`, `dispose` | 190 |
| `lib/src/game_module.dart` | `GameModule`, `GameViewer`, `GameSnapshot`, `ViewContext` | 70 |
| `lib/src/game_registry.dart` | `GameRegistry` (`GameRegistry([modules])`, `moduleFor(id)`) | 35 |
| `lib/src/hosting_settings.dart` | `HostingSettings` (`simStepS` = 1/60 fixed, `frameRateHz` 60 (20–60), `maxPlayoutFrames` 2 (0–4)), range-checked like `PuzzleSettings` (`settings.dart:44-55`) | 50 |
| `pubspec.yaml`, `analysis_options.yaml` | as above | 30 |
| `test/session_test.dart` | the §3 session tests (§5) | 270 |
| `test/support/fake_game.dart` | `FakeModule`, `FakeViewer`, `FakeSnapshot`, `CounterSession` for the loop tests | 90 |
| `test/registry_test.dart` | lookup, unknown id, duplicate id | 35 |

Every file is under 300 by estimate. `GameSession` holds `lateFrameMs = 25`, `stallS = 0.1` and `maxCatchUpS = 0.1`
as named constants with their reason (the values the views use today: `arena_view.dart:56,59`, `play_view.dart:173,195`
— the puzzle's bare `0.025`/`0.1` become these), so no new magic numbers.

Root `pubspec.yaml:8-17` gains `- packages/game_kit`; `tools/check.sh:9` gains `kit` in the list on the comment line and
the `checks` array (`:20-31`) gains
`"kit|packages/game_kit|flutter test|the session loop, modules and hosting settings"` after `metrics`.
`format` and `analyze` already cover it (`check.sh:21-22`).

## 2. Move map — the Arena first

`ArenaSession` (`lib/src/arena_session.dart`, ~200 lines) takes `host`, `game` (the `ArenaView.game` test hook),
`onEvent` and an optional `ArenaGame`. `ArenaView` builds it in `initState`, sets `paused`, calls
`advance` from the Ticker, `drawn` from a post-frame callback, `resize` from the `LayoutBuilder`, disposes it.

| Today (`arena_view.dart`) | Goes to |
| --- | --- |
| `:101-102` dt from elapsed, `_last` | `GameSession.advance` |
| `:103` paused check | `GameSession.advance` (returns; `_last` still updates) |
| `:105` `_feeds = feedsOf(host)` | `GameSession.advance` samples `players` + `gamepad` once an advance; the session's `ArenaSession` reads it |
| `:108-111` `_withLayout` set/clear, `setLayout` | `ArenaSession` (`resumed()` clears the set when `paused` goes false — today's `didUpdateWidget` `:81`) |
| `:112-115` frames/late | `GameSession` (counted per advance, as the views count ticks) |
| `:116-119` `round_start` record | `ArenaSession.step` |
| `:121-129` fresh inputs, `_arrived` | `GameSession.advance` (map handed to `drawn()`) |
| `:131-138` `_game.update`, haptic, sound, `onEvent`, record | `ArenaSession.step` (one step = one `update(simStepS, …)`) |
| `:139-153` `round_end` + frames record + reset | `ArenaSession.step` (on the step that flips playing → won) |
| `:154` `setState(snapshot)` | view: `setState` after `advance`, draws `session.current` |
| `:155-167` stall check, post-frame stage | `GameSession` (`stalled` from the advance's dt, reported by `drawn()`) |
| `:170-176` `_eventName` | `ArenaSession` |
| `:178` `_feed` (banner colour) | new `ArenaHud`/banner code, from the roster |
| `:180-218` `build` | stays, thin: `ArenaHud` + `ArenaField(onResize: session.resize)` |
| `:220-294` `_Hud` | `lib/src/arena_view_widgets.dart` as public `ArenaHud` (~120), roster instead of feeds |
| `:296-323` `_Banner` | same file as `ArenaBanner` |
| `:328-451` `ArenaPainter` | `lib/src/arena_painter.dart` (~130), roster `Map<String, ({int number, Color color})>` |
| `:11-21` `PlayerFeed`, `feedsOf`, `:24` `arenaGame`, `:27` `arenaLayout` | `arena_session.dart`; the drawing keeps a roster built in `build` from `host.players` (`ArenaRoster`) — Question 5 |

`ArenaSnapshot`, `ArenaPlayerView` and the `snapshot()` extension (`arena.dart:490-695`, 206 lines) move unchanged to
`lib/src/arena_snapshot.dart`, which gains `lerpTo` (§4) → ~270; `arena.dart` drops to ~489 and gets **no** new code.
`arena_module.dart` (~80, new): `arenaModule`, `ArenaViewer.decode/build`, `arenaSetup = {}`.

### Shape Race

`PuzzleSession` (`lib/src/puzzle_session.dart`, ~190) takes `host`, `puzzle`, `teams`, `random`, `match` and
`playtest` (`PuzzleSettings Function()`, today's `settings`), plus `onFinished`.

| Today (`play_view.dart`) | Goes to |
| --- | --- |
| `:95-97` match creation | `PuzzleSession` (the state keeps `match` as a getter) |
| `:113-121` `round_start` record | `PuzzleSession` constructor |
| `:129` `_withLayout.clear()` on resume | `PuzzleSession.resumed()` |
| `:135-137` hide statuses on dispose | `PuzzleSession.dispose` |
| `:145-147` dt, `_last`, paused | `GameSession.advance` |
| `:149` `match.settings = settings()` | `PuzzleSession.step` |
| `:150` `host.players` | `GameSession.advance` sample |
| `:152-161` layouts (`puzzleLayout`, `puzzleWatchLayout` `:20-43`) | `PuzzleSession.step`; the two layouts move to `puzzle_session.dart` |
| `:163-174` fresh + frames/late | `GameSession.advance` |
| `:176-180` `match.update` | `PuzzleSession.step` |
| `:181-188` sounds, `playSound` | `GameSession.sound` (once per advance) + `puzzle_events.dart` |
| `:182-184, 216-246` `_onEvent`, `_onSide` | `lib/src/puzzle_events.dart` (~60) |
| `:185, 250-302` `_report` | `lib/src/puzzle_report.dart` (~80), called once from `step` (`_reported` flag) |
| `:189-192` `setStatus`, `_withStatus` | `PuzzleSession.step` / `dispose` |
| `:193` `setState` | view: `setState` after `advance` |
| `:195-203` stall + post-frame stage | `GameSession` |
| `:305-335` `_statusFor` | `lib/src/puzzle_status.dart` (~45) |
| `:337-339` `build` | stays: `MatchView(puzzle, session.current, timeLimitS)` |

`play_view.dart` drops to ~110, `snapshot.dart` grows 189 → ~265 (`lerpTo`, §4); `game.dart` and `view.dart` are
untouched. `puzzle_module.dart` (~110, new): `shapeRaceModule`, `ShapeRaceViewer`, `shapeRaceSetup`.

## 3. Timing

`advance(elapsed)`: `dtS = (elapsed − _last)` in s, `_last = elapsed`; return while `paused`; `dtS` clamped to
`maxCatchUpS` = 0.1 s (today's rule clamp, `game.dart:315`, `arena.dart:334`); `_accS += dtS`; `_nowMs = host.nowMs`;
while `_accS >= simStepS`: `step(simStepS)`, `_accS -= simStepS`, `stepCount++`, and the step's
`atS = _nowMs − _accS * 1000`. Steps of one advance therefore share the advance's input sample and get evenly spaced
`at`s (100 ms advance → `atMs` 17, 33, 50, 67, 83, 100 back to front).
- **Frames**: the first step fixes `_frameStartAtS`; a step publishes when
  `k = floor((atS − _frameStartAtS) / (1000 / frameRateHz))` is above the last `k`, and only when `host.hasViewers`.
  Compare in doubles (int `atMs` would skip a 60 Hz frame); the wire carries `round(atS)`. `n = stepCount − 1`.
  `snd` = sounds since the last published frame; `acks` from `host.inputSeq`; `pl` from `host.players`.
- **Pause**: `paused = true` → no step, no accumulate; resume does not catch up. Setting it false calls `resumed()`.
- **frames/late** (`arena_view.dart:112-115`, `play_view.dart:171-174`) count advances that had players, late when the
  advance's raw dt is over `lateFrameMs` (25) and it isn't the first. Today they count ticks; one advance is one tick.
- **received_to_drawn** (`arena_view.dart:155-167`, `play_view.dart:195-203`): `advance` records the fresh inputs
  (`inputArrivedAtMs`, `_arrived`) and `stalled = rawDt > stallS`; the view's post-frame callback calls `drawn()`, which
  reports `host.nowMs − at` once per fresh input and clears it — one sample per drawn frame, as today. Nothing is
  reported while paused (the view returns before the callback) or after a stall.

## 4. The modules, the setup and `lerpTo`

- `shapeRaceModule`: id `shape_race`, `snapshotVersion = MatchSnapshot.version` (`snapshot.dart:161`),
  `createViewer(setup)` reads `{puzzle, level, timeLimitS, teams}` (built by `shapeRaceSetup` from
  `match.puzzle.id`, `puzzle.level.name`, `sides.first.game.settings.timeLimitS`, `{id: side.name}`). `decode` is
  `MatchSnapshot.fromJson`; `build` is `MatchView(puzzle, snapshot, timeLimitS: setup['timeLimitS'])`. The puzzle is
  found by id in `PuzzleLibrary` (`library.dart:34`) — **Question 1** (the load is async).
- `arenaModule`: id `arena`, `snapshotVersion = ArenaSnapshot.version` (`arena.dart:578`), setup `{}`; `decode` is
  `ArenaSnapshot.fromJson`; `build` is `ArenaHud` + `ArenaField` + `ArenaBanner` from the snapshot and `view.roster`
  (`Color(playerColor(number))`); `view.playerId` is unused in s3b.
- `lerpTo` (contract §4: t = 0 and 1 are the inputs, positions lerp, angles the shortest arc, the rest from `a`):

| Snapshot | lerps | shortest arc | from `a` (discrete) |
| --- | --- | --- | --- |
| `MatchSnapshot` | `boards` pairwise by index | – | `seed`, extra boards |
| `PuzzleSnapshot` | piece/player `x,y` | piece `angle` (degrees, arc over 360: 350→10 at 0.5 is 0) | `puzzleId`, `timeLeftMs`, `warning`, `phase`, `state`, `holders`, `calling`, `order`, `readyTargets`, `hintTargets`, `finishTimeMs`, player `number`/`held` |
| `ArenaSnapshot` | player `x,y`, `cooldown`, `aimX/aimY`; `roundTimeS`, `breakLeftS`; `hazards` pairwise | – | `round`, `phase`, `walls`, `goal`, `start` (fixed in a round; the mirror flip is discrete), `winnerId`, `lastTimeS`, `bestTimeS`, `bestId`, `playerRadius`, `hazardRadius`, and the per-player flags/counters |
| all | – | – | players or pieces only in `b` are not drawn (only `a`'s are iterated) |

- **Roster replaces the live list (survey Conflict 4) in drawing only**: `ArenaHud`/`ArenaPainter`/`ArenaBanner` take
  `ArenaRoster`; the TV builds it in `build` from `host.players` (`nickname ?? ''`), the viewer from `view.roster`.
  The rules and the session still read `host.players` for gamepads, layouts and statuses.

## 5. Test map

Counts today: `view_test` 7, `arena_view_test` 10, `game_screen_test` 6, `puzzle_results_test` 4,
`puzzle_screen_test` 2, `pause_menu_test` 2, `games_screen_test` 1, `keyboard_player_test` 1 (survey answer 10).
Steps for a pump count n of 16 ms: `floor(0.96 n)`; today n ticks of 0.016 s.

| Test | Pumps | Steps now | Expected change |
| --- | --- | --- | --- |
| `view_test.dart:85,104,117,135` (drawing) | none | – | none |
| `:187` Pick up/Rotate, panel | 2/press, 100 ms | 6 in 100 ms (6.25 today) | none (18° of turn both) |
| `:212` snap/wrong buzz | 2/press | 1/advance | none; presses covered by the latch (R1) |
| `:233` finish report | 2/press | 1/advance | none: snaps 4, placed 4, win 1 |
| `arena_view_test.dart:38` walk, dash | 60 + 1 | 57 + 1 | none: wall at step 11 (was update 11), `Hits 1`, rumble |
| `:56` two sprites | 60 | 57 | none |
| `:78` keyboard | 60 | 57 | none |
| `:91` resize | 1 | 0 | none: `resize` is still called from `build` |
| `:102,:120` winner/Goal | ≤400 | goal at step ~152 → ~159 pumps | none |
| `:132` stall | 2 s + 3 | 6 in the 2 s advance | none: still no sample after the stall |
| `:150` records | ≤400 | ~152 steps → 159 advances | none: `drawn > 10` (~150) |
| `:174,:193` | 60 / none | 57 | none |
| `game_screen_test.dart:25,77,122` | 90 | 86 | none: rumble first, hit after |
| `:38,57,69` | ≤5 | 1–4 | none |
| `games_screen_test.dart:9` | 0 | – | none |
| `pause_menu_test.dart:12,84` | 63 paused | 0 | none: clock frozen |
| `puzzle_screen_test.dart:11,47` | 2–5 | 0–4 | none: `Done!`/`Time's up!` still reachable |
| `puzzle_results_test.dart:14,75,131,162` | 2–3/press | 1/press | none |
| `keyboard_player_test.dart:9` | 30 | 28 | none |

New tests, one line each:
- `game_kit/test/session_test.dart`: fixed steps for any pump pattern (60 × 16 ms → 57, 90 × 16 ms → 86); 2 s advance → 6 steps, next 16 ms adds 1; no steps or frames while paused; no frames without `hasViewers` but steps still run; frames 57 / 29 / 19 at 60 / 30 / 20 Hz over those 57 steps; `at` evenly spaced within one advance (17, 33, 50, 67, 83, 100); a sound called twice in one advance plays once and is carried once; `startView` on construction (id, sv, setup, hz) and `view_end` quit/finished, once; `acks` and `pl` from the host; dispose leaves nothing ticking.
- `game_kit/test/registry_test.dart`: a module by id, an unknown id is null, a duplicate id throws.
- `test_game/test/arena_snapshot_test.dart`: `lerpTo` t = 0 and 1 reproduce each snapshot's `encode()`; a player's `x` at 0.5; a player only in `b` is not drawn; `walls`/`round` from `a`.
- `test_game/test/arena_session_test.dart`: one round_start, one round_end and one frames record per round; `round_end.timeS` equals the step the win happened on; `resize` reaches the game; the roster names from a `MemoryGameHost`.
- `puzzle_game/test/snapshot_lerp_test.dart`: t = 0/1; an angle 350→10 at 0.5 is 0; a piece added in `b` is not drawn; held/holders/phase from `a`.
- `puzzle_game/test/puzzle_session_test.dart`: one `player_result` per player and one `round_end` after the finish and many more advances; the clock stops at the result; `view_start`'s setup has the four keys; status hidden on dispose.
- `puzzle_game/test/frame_size_test.dart`: a real 4-player split boat `MatchSnapshot` (2 boards × 6 pieces, 4 players) in a `FrameMessage` with sounds, acks and a 4-name roster encodes under 2500 bytes (s3a-g2 Q6; the estimate is ~700–750).

## 6. Risks

- **R1 A 16 ms press in an advance with no step.** `MemoryGameHost` holds nothing (`memory_game_host.dart:65-68`), and
  with 16 ms pumps, pumps 1, 26 and 51 of a run (then one in 25) run no step: a press landing on one would vanish.
  `GameSession` samples the host once an advance, latches the buttons seen since the last step and ORs them into the next
  step's buttons (analogues from the newest sample); the step after that sees the release. It covers one lost frame: a release still has to reach a step
  before the next press, which holds in every test (§5). Real hosts also hold presses 50 ms (`server_game_host.dart:30`).
  Question 3.
- **R2 A sound or haptic twice in one advance.** Sounds are collected per advance and played once (`GameSession.sound`);
  haptics stay per event, and the rules' gaps bound repeats (`hitGapS` 0.3 s `arena.dart:202`, the dash cooldown). The
  `Hits 1` and `Dashes 1` checks (§5) prove it.
- **R3 The puzzle's report firing once.** `_reported` moves into `PuzzleSession.step`; the new session test drives 100
  advances past the finish and counts the records.
- **R4 Rematch / change teams.** `PuzzleScreen` pushes a new screen (`puzzle_screen.dart:122-126`), so the old view
  disposes its session (view_end `quit`) and a new one starts (`startView`) — today's order. `puzzle_results_test`
  covers it, plus a `viewEnds`/`viewStarts` count in the new session test.
- **R5 A timer that counted ticks.** None: the puzzle clock and the arena break integrate `dt` (`game.dart:316-321`,
  `arena.dart:344-353`), and 1/60 steps sum to the same time (±1 %, §5). The views' frames/late keep counting advances.
- **R6 The keyboard player.** Its input reaches `gamepad` through `LocalPlayer` (`server_game_host.dart:138-147`) and
  `inputArrivedAtMs` is null for it, so it is never measured — unchanged; `keyboard_player_test` stays green.
- **R7 Pause.** The pause menu's 63 pumps must not move the clock: `advance` returns before the accumulator.
- **R8 A frame before `startView` / after `endView`.** `publishFrame` is ignored by the host then (`game_host.dart:84-90`);
  s3c's `FrameView` already ignores frames before a start (STATUS note).

## 7. Questions (contract items that don't fit the code)

1. `shapeRaceModule.createViewer` is synchronous (contract §4) but the puzzle comes from `PuzzleLibrary.load()`, which is
   async and reads `rootBundle` (`library.dart:18-29`). Plan: the viewer starts one cached load on first build and draws
   nothing until it resolves; a setup naming an unknown puzzle can't throw from `createViewer`. Give the module a
   library (which changes the `GameRegistry([shapeRaceModule, arenaModule])` line), or accept the lazy load?
2. `setup.timeLimitS` is frozen at `startView`, while the playing view reads the live `PuzzleSettings` every frame
   (`play_view.dart:149,339`) and the host's settings screen can change it mid-match. Plan: the viewer's clock bar uses
   the setup value. Confirm.
3. The input latch (R1) is not in the contract's text; it is ~12 lines in `GameSession`. Confirm, or should a lost
   one-frame press be accepted?
4. `n` = `stepCount − 1` (contract: "step number from 0"), so the first frame is `n` 0. Confirm.
5. Removing `PlayerFeed` and `feedsOf` (public through `test_game.dart:5-6`, used only in `arena_view.dart:11-21`) in
   favour of `ArenaRoster`. Confirm.
6. `ArenaSnapshot`/`ArenaPlayerView`/the `snapshot()` extension move out of `arena.dart` (695 → ~489) so `lerpTo` has a
   home (§2). A pure move plus `lerpTo`; confirm it belongs to this job.
7. The Arena's `dispose(finished:)` is always `quit`: a won round is not the end of the session. Confirm.
8. `PuzzleSnapshot.lerpTo` pairs pieces by index (both boards always hold the same puzzle). Confirm, since the contract
   only says "pieces only in [next] aren't drawn yet".

## 8. Gates

- **G3** = `game_kit` (all files, `kit` check) + the Arena: `ArenaSession`, the thin `ArenaView`, `arena_snapshot.dart`,
  `arena_module.dart`, their tests; `test_game` and `game_kit` in the workspace; all checks green. `party_host` needs no
  change (both views keep their constructors, §0), so the `host`, `tv` and `phone` checks stay green.
- **G4** = Shape Race the same way (`PuzzleSession`, the four moved helpers, the module, `snapshot.dart`'s `lerpTo`, the
  frame size test), plus the full `tools/check.sh`. No adjustment needed; each gate leaves the workspace compiling and
  every test running, and `puzzle_game` is untouched until G4.
