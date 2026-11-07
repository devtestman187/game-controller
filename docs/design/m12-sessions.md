# M12 step 3 contract: sessions, frames, playout and stages

The types for [m12.md §2.3 to §2.5 and §3](m12.md) (fixes B4). They're Claude's contract: the worker implements them as written. A change goes back to Claude first. Facts it rests on: the G0 survey, [s3-g0-survey.md](../briefs/m12/s3-g0-survey.md) (cited as "survey").

**Goal:** the host runs each game in fixed 1/60 s steps inside a `GameSession`, not inside its widget, and after each step can send a frame (snapshot, sounds, input acks) to controllers that listed `view`. A joined phone can buffer those frames, draw them smoothly, and measure touch-to-frame exactly (D3). On a TV nothing visible changes. The step ends with a host-side measurement on the PC; the measurement on phones is in step 6 (Nov 7).

## 0. Decisions on the survey's conflicts

| # | Conflict (survey) | Decision |
| --- | --- | --- |
| 1, 7 | A registry in `game_kit` holding both games is a cycle | `game_kit` defines the interfaces and an empty `GameRegistry` class. Each game package depends on `game_kit` and exports its module (`shapeRaceModule`, `arenaModule`). Apps build the registry: `GameRegistry([shapeRaceModule, arenaModule])` |
| 2 | `GameHost` can't send frames | New `GameHost` members (§2). `HostServer.capabilityFor` maps the three view messages to `Capability.view`, so `sendToAll` already reaches only viewers |
| 3 | `GameHost` has no input `seq` | New `GameHost.inputSeq(playerId)`: the seq of the input `gamepad()` returns now |
| 4, 6 | Arena numbers and names, and the puzzle's time limit, come from live objects | Every frame carries the roster (`pl`: number and name per player). The time limit goes in the puzzle's `setup`. Snapshots stay name-free and keep version 1 |
| 5 | `ArenaView` resizes the rules | `ArenaSession.resize(Size)`, called by the host's view as today. The snapshot is already in fractions of the field (`arena_view.dart:191`), so viewers don't need the size |
| 8 | The metrics `data` whitelist drops new fields | Raw samples go in a new top-level `stages` field of the metrics batch. The host feeds each one into `reportStage`, the path the session summary already reads |
| 9 | Effects and records live in the views | They move into the sessions with the loop. The views keep only drawing |
| 10 | Sounds are one stream on the host | Unchanged on a TV. Frames carry the sound names too (`snd`); phones playing them is step 6 |
| — | m12.md §2.3's `GameModule.createSession` | Dropped. The host screens are game-specific (`PuzzleScreen` and `GameScreen` own setup and rematch), so they build their session directly. The registry serves viewers. Add a factory when something generic needs one |
| — | D3's `frame_received` needs the phone to know the host's clock, and the phone doesn't estimate it | Replaced by `frame_jitter`: a frame's arrival delay above the fastest frame of the last 2 s. It's exact on one clock, and it's what sizes the playout delay |

## 1. Protocol (`packages/protocol`, all behind `Capability.view`; protocol version stays 1)

| Message | Fields (wire key: meaning) |
| --- | --- |
| `ViewStartMessage` (`view_start`, host → viewer) | `game`: module ID · `sv`: snapshot version · `setup`: module JSON · `hz`: frame rate |
| `FrameMessage` (`frame`, host → viewer) | `n`: step number from 0 · `at`: host ms of that step (§3) · `s`: snapshot JSON · `snd`: sound names since the last sent frame (omitted when empty) · `acks`: player ID → last applied input seq (only players with one) · `pl`: player ID → `[number, name]` (name `""` when none) |
| `ViewEndMessage` (`view_end`, host → viewer) | `reason`: `finished`, `quit` or `abandoned` (`ViewEndReason` constants) |
| `MetricsMessage`, new optional fields (viewer → host) | `stages`: stage name → list of ms ints, at most `maxStageSamples` = 256 per stage per batch · `view`: `{frames, gaps, late}` counts for the batch |

- Decoding throws `FormatException` naming the field, like the other messages. `acks`, `pl` and `stages` keys are strings and values are checked. Unknown stage names are kept; they're names, not code.
- `Capability.view` loses "Reserved". A controller that lists it gets the three messages. The phone app lists it only with the test option of §6 on, until step 6.
- `docs/protocol.md` gets a "Viewing the game (M12)" section with the table above and §3's timing rule.
- Tests: round trip, every field's error, old peers (an older controller never gets a view message, as the pattern in `connection/test/m10_test.dart:63-86`). A 4-player Shape Race frame (split board, all players holding pieces) is under 2.5 KB encoded.

## 2. Connection (`packages/connection`)

### `GameHost`, new members

```dart
/// True while at least one paired controller listed Capability.view. A
/// session skips building frames when nobody would get them.
bool get hasViewers;

/// The seq of the input [gamepad] returns for [playerId] now: the last
/// applied InputStateMessage.seq. Null for a local player or before any input.
int? inputSeq(String playerId);

/// A game starts being shown on viewers. Sent to every viewer now, and to
/// any viewer that pairs later until [endView], followed by the latest frame.
void startView(ViewStartMessage start);

/// One frame, to every viewer. Encoded once, the same text to each.
/// Ignored before startView or after endView.
void publishFrame(FrameMessage frame);

/// The game stopped being shown. Sent to every viewer; forgets the start
/// and the latest frame.
void endView(ViewEndMessage end);
```

- `ServerGameHost` implements them as written. `MemoryGameHost` keeps them in lists (`viewStarts`, `frames`, `viewEnds`) with a settable `hasViewers` (default false) and `inputSeqs` map, for tests.
- Each sample in a metrics batch's `stages` becomes `reportStage(controllerId, stage, ms)` on the host that received it, so it reaches `stages`, `stageSummary` and the session summary like the host's own stages.
- `LatencyStage` gains `touchToFrame = 'touch_to_frame'` and `frameJitter = 'frame_jitter'`, with doc comments from §4.

### The controller side

- `ControllerClient` exposes `Stream<ViewEvent> get view`: `ViewStarted(ViewStartMessage)`, `ViewFrame(FrameMessage, int arrivedAtMs)` (the phone's clock, taken on receipt) and `ViewEnded(ViewEndMessage)`, sealed. Only when the client listed `view`; otherwise those messages are ignored as unexpected.
- `controller_client.dart` is at 400 lines (tech debt): split it first, a pure move, before adding anything. No other file over 300 grows past 400.
- `ViewerTiming` (new, pure Dart, `lib/src/viewer_timing.dart`): §4's arithmetic, so that both the phone's `FrameView` and `sim_controller` use it. It holds no frames. `PlayoutBuffer<T>` (same file) holds them and picks `a`, `b` and `t` for a render time.
- `ViewerStats` (new, pure Dart): collects §4's samples and counts. `drain()` returns them for one metrics batch, capped at `maxStageSamples` per stage by keeping evenly spaced samples (index `i * count ~/ cap`), and empties itself.

## 3. The host loop (`packages/game_kit`, new Flutter package)

```dart
/// One game's rules on the host, in fixed steps (m12 §2.3). Subclasses run
/// the rules and their effects; this class owns time, frames and the view.
abstract class GameSession {
  GameSession({required this.host, required this.module, required Map<String, Object?> setup,
      this.settings = const HostingSettings()});

  /// Advances the rules by exactly settings.simStepS. Applies the step's
  /// effects through host: haptics, records, layouts, status; calls
  /// [sound] for each sound.
  @protected
  void step(double dt);

  /// The rules' state now, for drawing.
  @protected
  GameSnapshot snapshot();

  /// Plays [name] on the host (once per [advance], as today) and adds it to
  /// the next frame's snd.
  @protected
  void sound(String name);

  /// Called once per drawn frame by the host view's Ticker, with the
  /// Ticker's elapsed time. Runs as many steps as the time since the last
  /// call allows (at most maxCatchUpS = 0.1 s of it, as the rules' clamp
  /// today), and publishes frames. Does nothing while paused, and resuming
  /// doesn't catch up.
  void advance(Duration elapsed);

  /// The host view drew the frame built by the last advance: reports
  /// received_to_drawn for inputs that were fresh in it (not after a
  /// stall over stallS = 0.1 s), exactly as the views do today.
  void drawn();

  bool paused;
  GameSnapshot get current;
  int get stepCount;

  /// Ends the view (view_end: finished if [finished], else quit) and stops.
  /// Calling it again does nothing.
  void dispose({bool finished = false});
}
```

- **Frames.** On construction the session calls `host.startView` (`game`: module ID, `sv`: module's snapshot version, `setup`, `hz`: `settings.frameRateHz`). After a step whose host time is at or past the next send time (every `1000 / frameRateHz` ms, from the first step), and only when `host.hasViewers`, it publishes `n`, `at`, `snapshot().toJson()`, the sounds since the last sent frame, `acks` from `host.inputSeq` per player, and `pl` from `host.players`.
- **`at` of a step:** `host.nowMs` at the `advance` minus the time still unsimulated after that step, rounded to ms. So steps run together in one `advance` get evenly spaced times, and a stall or pause shows as real time passing.
- **Frames and late frames** (the records `frames`/`late` the views keep today) count `advance` calls, as the views count ticks today; they move with the code that records them.
- **`HostingSettings`** (in `game_kit`, documented and range-checked like `PuzzleSettings`): `simStepS` = 1/60 (fixed), `frameRateHz` = 60 (20 to 60), `maxPlayoutFrames` = 2 (0 to 4). The other settings in m12.md §4 are added by the steps that use them.
- **`PuzzleSession`** (puzzle_game) and **`ArenaSession`** (test_game) take over everything in `_tick` after the paused check (survey answer 1): settings, layouts, effects, records, the result report and `onFinished` (puzzle), `onEvent` and the round records (arena). `ArenaSession.resize(Size)` replaces the view's `_game.resize`.
- **The views** (`PuzzlePlayView`, `ArenaView`) keep their public constructors and test hooks (`PuzzlePlayViewState.snapshot`, `ArenaView.game`). Each builds its session in `initState`, calls `advance` from its Ticker and `drawn` from a post-frame callback, draws `session.current`, and disposes the session.
- **The Arena draws from the frame's roster** where it reads the live player list today. The host view builds the same roster from `host.players`, so the TV and a viewer draw from the same inputs.
- **Tests:** the rules' tests stay as they are. View and screen tests may change only expected values that come from step timing (16 ms pumps against 16.7 ms steps), and the report lists each change, old value to new value. New session tests with `MemoryGameHost`: fixed steps for any pump pattern; at most 0.1 s caught up; no steps or frames while paused or without viewers; frames at the rate for 20, 30 and 60 Hz; `at` evenly spaced within one advance; sounds both played once per advance and carried once in a frame; acks; startView on construction and view_end on dispose with the right reason; a viewer pairing mid-game gets the start and the latest frame (connection test).

## 4. The viewer (`ViewerTiming`, `ViewerStats` in connection; `FrameView` in game_kit)

**Playout** (all ms; `skew` = a frame's arrival time on the phone − its `at`):
- `base` = the smallest skew among frames that arrived in the last `windowMs` = 2000.
- A frame's `lateness` = its skew − `base` (≥ 0). This is the `frame_jitter` sample, one per frame.
- `playoutDelayMs` = the 95th percentile of lateness over the window, clamped to [0, `maxPlayoutFrames` × 1000 / `hz`].
- To draw at phone time `now`, render host time `r` = `now` − `base` − `playoutDelayMs`. With frames `a` and `b` such that `a.at` ≤ `r` < `b.at`, draw `a.snapshot.lerpTo(b.snapshot, (r − a.at) / (b.at − a.at))`. If `r` is at or after the newest frame, draw the newest (never extrapolate). If `r` is before the oldest kept frame, draw the oldest. Frames older than `a` are dropped.
- `ViewStarted` resets everything.

**Measurements** (phone clock only; the two bullets were revised Nov 7 — the earlier ones measured only the newest input and counted a draw late after a fixed 25 ms, which held only at 60 Hz):
- `touch_to_frame`: `ViewerStats` remembers when each of the phone's input seqs was sent (the last 256). When a drawn frame first acks a seq above the last acknowledged one, it records one sample per remembered input seq in (last acknowledged, ack seq]: draw time − that input's send time, in seq order. So every input sent gets its trip to the screen, and the samples show the wait for the frame that first carried it. Inputs no longer remembered are skipped. Draw time is the post-frame callback of the Flutter frame that showed it.
- `gaps`: frames whose `n` jumps by more than 1.5 × the expected stride (60 / `hz` steps). `late`: drawn frames more than `lateFactor` = 1.5 × (1000 / `hz`) ms after the previous one, so the limit follows the frame rate (25 ms at 60 Hz, 50 at 30, 75 at 20) instead of fitting only 60 Hz. `frames`: frames drawn.

**`GameModule`, `GameViewer`, `GameSnapshot`** (game_kit):

```dart
abstract interface class GameModule {
  String get id;
  int get snapshotVersion;

  /// A viewer for one game, from view_start's setup. Throws FormatException.
  GameViewer createViewer(Map<String, Object?> setup);
}

abstract interface class GameViewer {
  /// Throws FormatException.
  GameSnapshot decode(Map<String, Object?> json);

  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view);
}

/// A game's drawable state. lerpTo is rule-free: positions lerp, angles take
/// the shortest arc, everything else (phase, ids, counts, who holds what) is
/// this snapshot's. Players or pieces only in [next] aren't drawn yet.
abstract interface class GameSnapshot {
  Map<String, Object?> toJson();
  GameSnapshot lerpTo(GameSnapshot next, double t);
}

/// What a viewer draws for: the roster (number and name per player ID) and
/// this phone's player, if it plays.
typedef ViewContext = ({Map<String, ({int number, String name})> roster, String? playerId});
```

- `MatchSnapshot` and `ArenaSnapshot` implement `GameSnapshot`. The puzzle's `setup` is `{puzzle, level, timeLimitS, teams}`. Its viewer finds the puzzle by ID in the shared files. The Arena's is `{}`.
- `FrameView` (game_kit) takes the client's `view` stream, a `GameRegistry` and the client's `ViewerStats`. It shows "Update the app to see this game" on an unknown module or a snapshot version mismatch, and nothing before the first frame. Otherwise it draws through `ViewerTiming` each Ticker frame.
- **Tests:** `ViewerTiming` with fixed numbers (Claude's cases go in the job brief): steady arrivals give delay 0; one late frame in 20 moves the delay to its lateness only while it's in the window; the clamp; hold at the newest; the oldest before the start; t exactly between two frames; a reset on view_start. `lerpTo` per snapshot type: t = 0 and 1 are the snapshots themselves; angles across ±π; discrete fields from `a`; a player only in `b`.

## 5. Packages

- `packages/game_kit`: Flutter, `resolution: workspace`, depends on `connection` and `protocol`. It goes in the root workspace list and gets a `kit` entry in `tools/check.sh` (`flutter test`).
- `puzzle_game` and `test_game` depend on `game_kit`. `party_host` and `controller_app` add it, `puzzle_game` and `test_game` (`controller_app` gets the games for viewing).

## 6. Measuring (the step's exit check)

- `sim_controller --view` lists `view` and uses `ViewerTiming` and `ViewerStats` without drawing. Its draw time is the moment `r` passes the frame. It prints a `touch_to_frame` and `frame_jitter` summary at the end and sends samples in its metrics batches.
- ~~The phone app's "Show the game view (test)" option~~ is dropped (Nov 7): the phone measurement moved to step 6, where a phone hosts and the joined phone shows `FrameView` for real, so a TV-hosted inset would be built only to be replaced. `FrameView` itself is still built and widget-tested in s3c.
- The metrics report prints `touch_to_frame` and `frame_jitter` (median, p95) and the view counts next to the input delay.
- `tools/smoke.sh` gets a `frames` step: a `--view` sim receives frames from the dev TV app during a game and reports a touch-to-frame median.
- **The measurement in step 3 (host side, on the PC):** the Windows TV app hosts Shape Race and the Arena for 2 minutes each, with a `--view` sim joined, at 60, 30 and 20 Hz (the development TV app takes the rate from a debug-only start option, added in s3c). Claude reads the host stages (`received_to_drawn`, frame sizes, late frames) and the sim's touch-to-frame and jitter from the report, and sends the owner TV screenshots of both games. This needs no device of the owner's. The emulator check is broken on this PC (project-notes, Tech debt) and isn't part of it.
- **The measurement on phones** moves to step 6 (m12.md §2.5): one phone hosts, one joins. The median should be under 50 ms; if not, the owner decides on D2 or local echo.

## 7. Jobs and gates

| Job | What | Gates |
| --- | --- | --- |
| s3a | §1, §2: messages, `GameHost` members, the client's `view` stream, `ViewerTiming`, `ViewerStats`, protocol.md | G2: the messages, `ViewerTiming`, `PlayoutBuffer`, `ViewerStats`, the stage names, with tests (self-contained, so checks pass) → G4: the `controller_client.dart` split, `GameHost` members, the server and client wiring, protocol.md |
| s3b | §3, §4's game_kit types, §5: the sessions, the thin views, the modules and `lerpTo` | G1 plan (it moves both loops) → G3 the Arena → G4 Shape Race |
| s3c | `FrameView`, §6's tools, report and smoke step, the debug rate option | G2 → G4; then the PC measurement |

s3a and the start of s3b touch different packages and may run in parallel; s3b's G3 needs s3a's `GameHost` members.
