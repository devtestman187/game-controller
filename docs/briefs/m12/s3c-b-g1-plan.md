# M12 step 3c-b — G1 plan: the measuring tools

Job: [s3c-b-g1.md](s3c-b-g1.md). Contract: [m12-sessions.md](../design/m12-sessions.md) §1, §2, §4, §6 — it wins.
Read with it: [coding-guidelines.md](../../coding-guidelines.md), [s3b-g1-plan.md](s3b-g1-plan.md) §2 (the session
API this plan is written against). Line numbers are today's files: **s3a has landed, s3b G4 and s3c-a have not.**

## 0. Facts that shape the plan

**Already there (s3a)**
- `ControllerClient.view` (`controller_client.dart:131`) hands out `ViewEvent`s: `ViewStarted`, `ViewFrame(frame,
  arrivedAtMs)`, `ViewEnded` (`client_controls.dart:104-131`). `arrivedAtMs` is `_host.nowMs`
  (`client_messages.dart:72`), which is `_clock.elapsedMilliseconds` (`controller_client.dart:260`, private).
- `ViewerStats` (`viewer_stats.dart:13`): `inputSent(seq, atMs)` keeps the last 256 send times (`:51-56`),
  `frameArrived(n, jitterMs:)` (`:62-67`), `frameDrawn(ackSeq, drawnAtMs)` (`:78-93`), and `drain()` (`:102-117`)
  returns `(stages, view)` **and empties itself**.
- `ViewerTiming` (`viewer_timing.dart:16`): `addFrame({atMs, arrivedAtMs})` returns the lateness (`:58-67`),
  `renderAtMs(nowMs)` (`:72`), `reset({hz})` (`:76`); `PlayoutBuffer.pick(renderAtMs)` (`:140-150`) returns
  `(a, b, t)` and drops older frames.
- `MetricsMessage` already carries `stages` and `view` (`protocol/lib/src/metrics.dart:24-25,56-60`), capped at
  `maxStageSamples = 256`. It has **no `copyWith`**: a batch with samples is a new message (`:16-30`).
- The report reads stages from the summary: `rowsOf` (`packages/metrics/lib/src/report.dart:134`) takes
  `player['stages']['sent_to_received']` and copies the median/p95 onto every one of the player's mode rows
  (`:177-178`). `SessionCollector.metrics()` (`session.dart:188-202`) is what receives a batch on the host
  (`session_recorder.dart:47-48`) and stores it **without** `stages`/`view`.

**Not as the design says**
- `m12-sessions.md:69` says `controller_client.dart` is 400 lines; it is **379**: s3a G4 already split it into
  `client_*.dart`. The "split it first, a pure move" precondition is met; this job only adds ~13 lines.
- s3c-a's `FrameView` takes `stats` (the client's `ViewerStats`) and `nowMs` (`ControllerClient.nowMs`). Neither
  exists on the client yet: only the private `_now` (`controller_client.dart:260`) and no viewer at all. Item 1
  adds both, so s3c-a's call site can be written as planned.
- The phone app does **not** list `Capability.view` (`controller_app/lib/src/storage.dart:34`: metrics, rating,
  layout, status). So after item 1 a phone still measures nothing and its batches are unchanged (item 1's "no
  change for a client without `view`" holds by construction, not by a flag).

**Where inputs and metrics batches are today (item 1)**
- Inputs leave the client in exactly two places, both `InputStateMessage`: `sendInput`
  (`controller_client.dart:173`, `if (_snap.isConnected) _send(_input.nextState(_now))`) and the state sent when
  pairing completes (`client_messages.dart:151`, `_host.send(_input.nextState(_host.nowMs))`).
- `seq` is the client's own counter: `ClientInput.nextState(sentAtMs)` does `seq: ++_seq` (`client_input.dart:45-60`),
  and the same object carries `sentAtMs` on the wire.
- Both paths end in `ControllerClient._send(Message)` (`controller_client.dart:306`) — the one funnel.
- Batches are built by the caller: the phone in `PhoneMetrics._flush` (`controller_app/lib/src/phone_metrics.dart:123-137`)
  and handed in through `PhoneMetrics(send: client.sendMetrics)` (`controller_app/lib/src/providers/metrics.dart:34`);
  the sim builds one every 10 s (`sim_controller.dart:135-159`). `ControllerClient.sendMetrics`
  (`:142-151`) puts it in `MetricsOutbox` and sends it if the host takes metrics; `_resendMetrics`
  (`client_messages.dart:175-181`) re-sends the **stored** messages after a reconnect.

**The sim today (item 2)** — `bin/sim_controller.dart`, 266 lines: usage `:26-39`, option parsing `:199-221`
(flags at `:203`, known names at `:217`), identity and capabilities `:83-96` (capabilities chosen at `:89`),
connection-start side effects `:108-129`, metrics timer `:135-159`, ping timer `:165-170`, the run ends through
`done` (timer `:171-175`, Ctrl+C `:176-178`, failure `:125-126`), the summary `:184-189`, then stop/dispose/exit
`:190-196`. Token-file helpers `:223-266` (44 lines). `--stream` is what sends inputs: `runStreamInput`
(`demo_input.dart:76-83`) sends a tilt state every 16667 µs with A held a quarter of every second, started at
`:119`.

**The metrics report today (item 3)** — `report.dart` (351): `ModeRow` `:5-108` (26 CSV columns `:75-78`), `rowsOf`
`:113-184`, `GroupStats` `:191-233`, `_median` `:235-239`, `groupBy` `:242-250`, `table` `:253-312` (18 headers
`:254-273`), `enjoyment` `:315-335`, `report` `:338-345`, `csv` `:347-351`. `session.dart` (424) holds four public
types: `DelayStats` `:7-44`, `RatingScheduler` `:46-77`, `HostType` `:79-85`, `SessionCollector` `:87-424`. There is
no per-controller **text** listing: a controller's numbers live on its mode rows (CSV) and in the group tables.

**Hosting settings and the session today (item 4)** — `hosting_settings.dart` (40) is a const class with asserts
(`:5-13`), `defaultFrameRateHz = 60`, `min/max 20/60` (`:28-30`), `defaults` (`:36`), `ranges` (`:39`).
`GameSession`'s constructor is `this.settings = const HostingSettings()` (`game_session.dart:28`) and uses
`settings.frameRateHz` for `startView` (`:30-37`). A `GameSession` is built in exactly two places after s3b G4:
`ArenaView.initState` (`test_game/lib/src/arena_view.dart:45`) and the puzzle's play view (today
`puzzle_game/lib/src/play_view.dart:56,95-97`; after s3b, `PuzzleSession` built there, [s3b-g1-plan.md](s3b-g1-plan.md) §2).
Neither passes settings, so a default reaches every session.

**The launch paths today (item 4)** — `tv_test_app/lib/main.dart:46` `home: const HomeScreen()`. Home →
`openPlay` (`home_screen.dart:213`, route `gamesRouteName` `:219`) → `GamesScreen` (`games_screen.dart:18`):
`pickShapeRace` `:38` → `ShapeRaceScreen` `:139` → `random-easy` `:164` → `JoinScreen` `:192` → sides picked by
the phones (`join_screen.dart:145-150` simulated, `:169-204` A/left/right/Start) → `PuzzleScreen`
(`:218-226`); `pickArena` `:46` → `GameScreen` `:50` **with no join screen**. Providers: `hostServiceProvider`
starts the host when first watched (`providers.dart:64-76`), `gameHostProvider` `:92`, `gamePlayersProvider` `:95`,
`puzzleLibraryProvider` `:254`. The home screen also starts sounds and the wakelock (`home_screen.dart:28,30`).

**The tools today** — `tv-dev.sh`: usage `:6-10`, `start` `:57-83` (refuses when running `:58-62`, truncates the
log `:64`, one hard-coded `flutter run` line `:67`, waits for `Listening on port` `:69-80`), `status` `:40-54`
(port and code from the newest log line `:34-38`). `tv-window.ps1`: keys are left/right/up/down/space/enter/esc/
tab/backspace/a-z/0-9 (`:12`). `smoke.sh`: helpers `lines_in` `:121-123`, `wait_line` `:129-137`, `ok/skip/bad`
`:143-163`, `tv_is_live`/`tv_line` `:165-185`, `sim_step` `:187-196`, `read_status` `:198-211`, `start_tv`
`:213-242` (two tries `:225-234`, keeps `started_tv`), the first sim run `:243-268`, the reconnect `:270-293`, the
emulator block `:315-376`.

## 1. Item 1 — the client wiring (files 1–3)

**New `lib/src/client_viewer.dart` (~50 lines, internal, not exported).** One responsibility: what a client that
shows the game measures, and how it goes into a batch.
- `final class ClientViewer` with `final ViewerStats stats;` (made with `hz: ViewerStats.simStepHz`; `FrameView`
  corrects it with `stats.reset(hz: start.hz)` on view_start, s3c-a), `void inputSent(InputStateMessage state)`
  (delegates to `stats.inputSent(state.seq, state.sentAtMs)`) and
  `MetricsMessage withSamples(MetricsMessage batch)` — `drain()` once, then rebuild the message with
  `stages:` and `view:` set (`MetricsMessage` copies `segment, index, mode, durationMs, ended, data`).
- Nothing else: no timing, no frames. The frame side belongs to `FrameView` (phone) and `SimView` (sim).

**`controller_client.dart` 379 → ~392 (+13), five edits**
1. import `client_viewer.dart`;
2. field `final ClientViewer? _viewer;`, initialised `identity.capabilities.contains(Capability.view) ? ClientViewer() : null`
   in the initialiser list after `_log` (`:41`) — the capability a client is built with is the one that matters;
3. `ViewerStats? get viewerStats => _viewer?.stats;` with a doc comment pointing at `FrameView` / s3c-a, next to
   `view` (`:131`);
4. `int get nowMs => _now;` with a doc comment ("the same clock as `ViewFrame.arrivedAtMs`, for FrameView"), next
   to `_now` (`:260`) — s3c-a needs it public; `_ClientHost.nowMs` (`:327`) can then be `_client.nowMs`;
5. `_send` (`:306`) records inputs, so no send path can forget it:
   `if (message is InputStateMessage) _viewer?.inputSent(message);`
   (using the state's own `sentAtMs`, the value the host measures against — no second clock read); and
   `sendMetrics` (`:142`) starts with `batch = _viewer?.withSamples(batch) ?? batch;` **before** `_metrics.add`, so a
   batch waiting in the outbox keeps its samples and a retried batch (`client_messages.dart:175-181`) is not drained
   twice.

Why `_send` and not the two call sites: both input paths (`:173`, `client_messages.dart:151`) converge there, and a
future third one does too. It is the smallest diff and it makes "every input it sends" true by construction.

**Reaches the phone app with no phone app edit.** `PhoneMetrics` builds a plain `MetricsMessage` and hands it to
`client.sendMetrics` (`providers/metrics.dart:34`); the client enriches it on the way out. Today
`storage.dart:34` lists no `view`, so `_viewer` is null, `withSamples` never runs and `_send`'s check never matches:
a client without `view` behaves exactly as now. When step 6 adds `Capability.view` to the phone, the same path
starts filling `stages`/`view` with no change in `controller_app`.

**Tests — new `test/client_view_test.dart` (~150; `view_test.dart` is 417 and does not grow).** With the package's
`FakeHost`/helpers: a client with `view` has `viewerStats`, one without has null; an input sent by `sendInput` and
then drawn by `frameDrawn(seq, t)` gives the next batch `stages['touch_to_frame'] == [t − sentAtMs]` and
`view.frames == 1`; the pairing-time state (`client_messages.dart:151`) is measured too (same funnel); a batch
queued while the host lists no metrics keeps its stages and re-sends them after pairing; a client without `view`
sends the same batch it was given (no stages, `view` null).

## 2. Item 2 — `sim_controller --view` (files 3, 4, 5)

**The split (266 → 246 + ~50 + ~130).**
- `bin/sim_token_file.dart` (new, ~50): today's `:223-266` moved verbatim — the `Pairing` typedef,
  `readTokenFile` (with its private `readText`) and `writeTokenFile`; `dart:convert` and `dart:io` come with them.
- `bin/sim_view.dart` (new, ~130): `SimView`, the "draw" without a screen, and its summary.
- `bin/sim_controller.dart` 266 → ~246: usage gains two lines (26 → 28), `--view` joins the flag test (`:203`) and
  the known set (`:217`), the capability list (`:89`) becomes a list with `if (options.containsKey(…))` elements
  (`metrics`, `rating`, `view`), the view is made and wired after the client (`:96`), and the summary prints it
  (`:189`). Imports lose `dart:convert` only if nothing else uses it — `:98` still does, so it stays.

**`SimView` (~130 lines): `ViewerTiming` + `PlayoutBuffer` + the client's `ViewerStats`, no drawing.**
- `SimView.of(ControllerClient client, {required String playerId})` — reads `client.viewerStats` once and throws
  `ArgumentError` when it is null (can't happen under `--view`, whose capability list is built at `:89`), and takes
  `nowMs: () => client.nowMs` so its clock is the one behind `arrivedAtMs`.
- `onEvent(ViewEvent)`: `ViewStarted` → `stats.reset(hz: start.hz)`, fresh `ViewerTiming(hz: start.hz)` (its
  `maxPlayoutFrames` default 2 is the contract's), `buffer.clear()`, `_lastDrawnN = null`; `ViewFrame` →
  `jitter = timing.addFrame(atMs: frame.atMs, arrivedAtMs: arrivedAtMs)`, `stats.frameArrived(frame.n, jitterMs: jitter)`,
  `buffer.add(frame, frame.atMs)`, and `_bytes.add(codec.encode(frame).length)`; `ViewEnded` → clear both and draw
  nothing more (as `FrameView` does).
- `start()`/`stop()`: `Timer.periodic(drawPeriod)` with `drawPeriod = Duration(microseconds: 16667)` — the same
  constant `runStreamInput` uses (`demo_input.dart:76`); the sim's "draw" is a timer at 60 Hz. Each tick:
  `pick = buffer.pick(timing.renderAtMs(nowMs()))`; null → nothing; `a = pick.a`; if `a.n` is above `_lastDrawnN`,
  set `_lastDrawnN = a.n` and `stats.frameDrawn(a.acks[playerId], nowMs())`. A frame therefore counts as drawn the
  first time `renderAtMs` passes its `at`, once per frame, never twice — no lerp, no snapshot decode.
- `playerId` is the sim's own controller id (`:72`): the host names a player by controller id
  (`server_game_host.dart:128-129`) and `acks` is keyed by it (`protocol/lib/src/view.dart:77`).
- Frame bytes: `MessageCodec().encode(frame).length` (`protocol/lib/src/codec.dart:35`) is exactly the text the host
  sent, so the mean and max are honest wire bytes; the cost (one encode per frame) is a dev tool's.
- `summary()`: `final d = stats.drain();` then two lines —
  `Touch to frame: <median> ms median, <p95> ms p95 (<n> samples)` and
  `Frames: <frames> drawn, <gaps> gaps, <late> late; frame size <mean> B mean, <max> B max`.
  Median and p95 by the same nearest-rank rule as `DelayStats.quantile` (`session.dart:27-36`) so the numbers agree
  with the report — a local `_quantile(List<int>, double)` (~6 lines, doc comment naming that rule; the histogram's
  2000 ms clamp is not copied, and isn't reached in practice). Bytes: a private `_ByteStats` with `meanBytes` and
  `maxBytes` (~12 lines) — not `RunningStats` (`rtt.dart:58-75`), whose fields are named `…Ms`.

**Inputs while viewing: `--stream`, yes.** Every state it sends is recorded by the client (item 1), the host acks the
newest seq in each frame (`acks`), and `frameDrawn` turns that into a sample, ~60 a second.

**Samples in batches:** the client puts `drain()`'s samples into every metrics batch, so `--metrics --view` together
send them (§6). Without `--metrics` nothing drains before the end, so the final `summary()` covers the whole run; with
both, it covers the time since the last batch, which the printed sample count shows. See Question 3.

**The sim's run, what it prints last.** `done` completes (`:171-178`), the summary line prints (`:186-189`), then
`view.stop()` and `view.summary()` — before `client.dispose()` (`:193`) — then exit. Nothing else about the run
changes. No unit test for `SimView` (Question 4): the arithmetic it uses is already tested
(`viewer_timing_test.dart`, `viewer_stats_test.dart`) and `tools/smoke.sh`'s frames step proves the wiring end to end.

## 3. Item 3 — the metrics report (files 7–15)

**`session.dart` 424 → ~355: split first, then add.** Three public types move out (guideline: one public type per
file; the file is over 400 and must not grow, coding-guidelines:39):
- `lib/src/delay_stats.dart` (new ~45): `DelayStats` (`:7-44`, verbatim).
- `lib/src/rating_scheduler.dart` (new ~40): `RatingScheduler` (`:46-77`, verbatim).
- `lib/src/host_type.dart` (new ~12): `HostType` (`:79-85`, verbatim).
`session.dart` then imports the three; `metrics.dart` gains three export lines (`:9-12` → 16 lines with
`report_table.dart`).

**What it records.** `_Player` (`:87-110`) gains `int viewFrames = 0, viewGaps = 0, viewLate = 0`;
`SessionCollector.metrics()` (`:188-202`) adds `batch.view`'s three counts (it already receives the whole batch,
`session_recorder.dart:47-48`); `summary()` adds `'view': {'frames': …, 'gaps': …, 'late': …}` next to `'stages'`
(`:328`) — only when a count is non-zero, like `'quitsMidGame'` (`:324`). The stored copy of the batch still drops
`stages`/`view` (as now): the counts are the player's, not the mode's.

**`report.dart` 351 → ~280, and a new `lib/src/report_table.dart` (~140).** `GroupStats` (`:191-233`), `_median`
(`:235-239`), `groupBy` (`:242-250`) and `table` (`:253-312`) move to the new file (the table's column list and
`GroupStats`' growing are the same responsibility: turning rows into numbers), exported from `metrics.dart`.
- `ModeRow` gains seven fields next to the input delay (`:63-64`): `touchMedianMs`, `touchP95Ms`, `jitterMedianMs`,
  `jitterP95Ms`, `viewFrames`, `viewGaps`, `viewLate`, filled by `rowsOf` from
  `player['stages']['touch_to_frame']`, `player['stages']['frame_jitter']` and `player['view']` — the same per-player
  copy onto each mode row that `inputMedianMs` does today (`:177-178`).
- CSV: the seven go at the **end** (`…,open_minutes,touch_median_ms,touch_p95_ms,jitter_median_ms,jitter_p95_ms,
  view_frames,view_gaps,view_late`) so `metrics_test.dart:291`'s `endsWith(',open_minutes')` still holds; the count
  goes 26 → 33 (`:294`).
- Tables: three new columns after `input ms` (`:272`), compact so the table stays readable —
  `touch ms` (`41/62`), `jitter ms` (`3/9`), `frames/gaps/late` (`720/3/5`), `-` when there are no samples; the CSV
  keeps the seven numeric columns for machines. `GroupStats` keeps the median of the rows' medians (`:208,227-228`)
  and sums the counts, like `presses`/`games` today.

**Tests.** `metrics_test.dart` (612, over the 500 test limit, must not grow): only `:294`'s 26 → 33 changes; every
other expectation keeps its meaning because the new columns are appended and empty summaries print `-`.
New `test/view_report_test.dart` (~120): a summary whose players have `stages.touch_to_frame = {n:2, median:41, p95:62}`
and `view = {frames: 720, gaps: 3, late: 5}` gives a mode row with those seven values, a table row containing
`41/62  3/9  720/3/5`, a CSV row of 33 fields ending `…,41,62,3,9,720,3,5`; a summary without `stages.touch_to_frame`
or `view` gives `-` in the table and empty CSV cells, and `report()` still contains `By input mode`.

## 4. Item 4 — the debug start options (files 16–22)

**`game_kit/lib/src/hosting_settings.dart` 40 → ~78.**
- `const int startFrameRateHz = int.fromEnvironment('FRAME_RATE_HZ', defaultValue: 0);` at the top with a doc
  comment (the same plain style as `tv_test_app/lib/src/app_info.dart:7` and `tv_host_setup.dart:13`).
- `factory HostingSettings.fromEnvironment() => kReleaseMode ? defaults : fromFrameRate(startFrameRateHz);`
  (`package:flutter/foundation.dart` for `kReleaseMode`; game_kit is a Flutter package).
- `factory HostingSettings.fromFrameRate(int hz)` — the testable half, no const: `0` (unset) → `defaultFrameRateHz`;
  `minFrameRateHz…maxFrameRateHz` → `HostingSettings(frameRateHz: hz)` (whose const asserts catch anything else);
  outside that → `throw ArgumentError.value(hz, 'hz', 'hz must be 20 to 60 (or 0 for unset)')`. A developer's typo
  fails loudly in debug; release never gets here.
- A non-const factory means `HostingSettings`'s default can no longer be a const default in `GameSession` (below).

**`game_kit/lib/src/game_session.dart` 272 → ~274.** `this.settings = const HostingSettings()` (`:28`) becomes
`HostingSettings? settings` in the parameter list and `settings = settings ?? HostingSettings.fromEnvironment()` in an
initialiser list; the field stays `final HostingSettings settings;`. That is the contract's only deviation
(§3 writes `this.settings = const HostingSettings()`) — Question 1. Nothing else in the file changes: `:30-37` and
`_publishIfDue` keep reading `settings.frameRateHz`.

**Every `GameSession` construction after s3b G4** — `ArenaView.initState` (`arena_view.dart:45`) and the puzzle's play
view (`play_view.dart:56,95-97` → `PuzzleSession`). Both pass no settings, so both get the environment's rate with no
change in `test_game`, `puzzle_game` or `party_host`. `FrameView`'s `settings` (s3c-a) is the *viewer's*
`maxPlayoutFrames`, a different thing; it stays `HostingSettings.defaults`.

**`tv_test_app/lib/src/debug_start.dart` (new ~70; nothing in `party_host`).**
- `const String startGame = String.fromEnvironment('START_GAME');` with a doc comment naming both new defines.
- `Widget? debugStartScreen()` — null unless `kDebugMode` and `startGame` is `arena` or `shape_race`; null for
  anything else (so `main.dart` writes `home: debugStartScreen() ?? const HomeScreen()`).
  `arena` → `const GameScreen()` (it takes no player, and a phone that pairs while the arena runs just appears).
  `shape_race` → `_ShapeRaceStart()`: a `ConsumerWidget` that watches `puzzleLibraryProvider` (`providers.dart:254`)
  and `gamePlayersProvider` (`:95`); until a player is connected and the library has loaded it shows a short
  "Waiting for a controller…" (the same text the arena shows, `game_screen.dart:115-127`); then it builds
  `PuzzleScreen(choice: PuzzleChoice(level: Level.easy, puzzleId: library.ofLevel(Level.easy).first.id),
  teams: {players.first.id: PuzzleSide.left})` — the first Easy puzzle, one team, whoever connected first
  (later joiners watch; `teams` is final in `PuzzleScreen`, `puzzle_screen.dart:46`). Both define the widget in
  `debug_start.dart`, and it watches `gameSoundsProvider` and `keepAwakeProvider` (`providers.dart:119`,
  `:222`) because the home screen did that (`home_screen.dart:28,30`) and games would otherwise be silent and the
  screen could sleep.
- `tv_test_app/lib/main.dart` 50 → 52: `home: debugStartScreen() ?? const HomeScreen()` (`:46`) and one import.

**What each path skips.** `--game arena`: the home screen (pairing code and addresses are then only in the app's own
log — `tools/tv-dev.sh status` reads the code from there, `tv-dev.sh:34-38`) and `GamesScreen`; the Arena never had a
join screen (`games_screen.dart:50`). Nothing else: the host starts on the first provider read (`providers.dart:64-76`,
via `gameHostProvider` in `GameScreen`). `--game shape_race`: the same, plus `ShapeRaceScreen`'s puzzle picker and
`JoinScreen` (side picking and the Start press, `join_screen.dart:169-226`). Release builds ignore both (the
`kDebugMode` check, plus `fromEnvironment()` returning `defaults`).

**Shortest path without the define (for comparison, not built):** `tools/tv-window.ps1 key enter` ×4 —
Play (focused), Shape Race (`autofocus` `games_screen.dart:42`), "Any Easy puzzle" (`autofocus: i == 0` `:167`),
then a phone must press A to join and A again to start. Whether Play really has the focus on the home screen is
unverified; a `down` may be needed first. It is one key sequence only for Shape Race, and the Arena would need
`down`+`enter` and then no join. At ~55 lines in `tv_test_app` and 0 in `party_host` the debug start is cheaper and
deterministic, so the key sequence stays a fallback.

**`tools/tv-dev.sh` 108 → ~126.** `start` takes `[--hz 20|30|60] [--game arena|shape_race]`: shift, read them,
refuse anything else with the usage text, refuse `--hz` values outside the three the brief names, then run
`flutter run -d windows "${defines[@]}"` at `:67` with `--dart-define=FRAME_RATE_HZ=…` / `--dart-define=START_GAME=…`
(a bash array, so the quoting stays right). When a copy is already running (`:58-62`) the flags are ignored by
`flutter run`, so it says so and points at `tools/tv-dev.sh stop`. The usage block (`:6-10`) gains the line.

**Tests.** `packages/game_kit/test/hosting_settings_test.dart` (new ~60): `fromFrameRate(0)` → 60,
`fromFrameRate(20/30/60)` keeps them, `fromFrameRate(19)` and `(61)` throw `ArgumentError`,
`maxPlayoutFrames` stays 2, `fromEnvironment()` is `defaults` in a test run (no define). The release branch can't be
tested (`kReleaseMode` is false under `flutter test`) — it is one line, proven by review. `tv_test_app/test/
debug_start_test.dart` (new ~70): with the app's existing test harness (`test/support/pump_app.dart`:
`pumpApp` `:34`, `puzzleLibraryProvider.overrideWith((ref) => testPuzzles())` `:54`, `testPuzzles()` `:81`,
`openArena` `:71`) — no game define → the home screen; `arena` → the
arena's screen with no controller (`game_screen.dart:115-127`); `shape_race` with no player → the waiting text, then a
fake player joins → `PuzzleScreen` for the first Easy puzzle with that player on the left side.

## 5. Item 5 — the smoke `frames` step (file 23)

**Where it goes: last** (after the reconnect step `:270-293` and after the emulator block `:315-376`), because it
restarts the TV app and a restart ends every pairing and truncates the log (`tv-dev.sh:64`).
**What it does**
1. If this run didn't start the TV app (`started_tv = 0`, someone's own dev copy — `start_tv` says so at
   `smoke.sh:216` and leaves it alone), `SKIP`: the step needs the app started with `--game arena` and must not kill a
   copy it didn't start.
2. `tools/tv-dev.sh stop`, then `start_tv --game arena` (the helper gains `"$@"` on its `start` line, keeping both
   tries `:225-234`), then `read_status` again for the new port, code and log (`:198-211`).
3. A second sim run, no token file (a fresh controller pairs with the code): `--view --stream --seconds
   "$sim_seconds"`, log `$out/sim-view.log`, waiting `sim_wait` (`:248-250`).
4. `sim_step frames "$out/sim-view.log" 'Touch to frame: [0-9]+ ms median'` — the sim's own line is the proof, so
   no TV-side log is needed (the TV log is often silent here, project-notes:59); then the whole touch/frames line
   pair is echoed with two spaces of indent, so the median and the frame size appear in the smoke output.

**How the steps and the run line up.** Today one 12 s sim run proves `hello`, `paired`, `player`, `ping`, `input`,
`metrics`, `disconnect` while the TV app sits on its home screen (`smoke.sh:252-268`); the TV app is never in a game,
so nothing could produce frames. The frames run is a second, independent pairing that pays for its own start: the sim
compiles nothing new (the package is built by then), pairs, is sent `view_start` and the latest frame (a viewer pairing
mid-game gets both, s3a), streams inputs, and prints its summary when `--seconds` runs out — which is the line the step
waits for, so `sim_step`'s timeout is `sim_wait` (12 + 20 s), not the default 20 s.
**Time added: about 45–90 s** — the dev build is already built but `flutter run` needs ~20–40 s to attach, `dart run`
~2–5 s, the run itself 12 s, and the waits poll twice a second. The smoke run goes from ~30 s to ~1.5–2 min
(`docs/dev-tools.md:14` says "about 30 seconds" and must change). With `--keep` the app is left running in the Arena,
not on the home screen — the docs say so.

## 6. Docs (file 24)

`docs/dev-tools.md` 404 → ~416 (already listed as tech debt at 400 lines, project-notes:50; the DeepSeek section split
stays tech debt, it isn't this job's): the `tools/tv-dev.sh start` block (`:195`) gains the two flags; the smoke section
(`:257-288`) gains the `frames` step in the step list (`:278`), the skip rule, and the new line pair in the sample
output; the duration in the table (`:14`) becomes "about 30 seconds, a minute longer with the frames step".

## 7. Every file, size now → after, in order

| # | File | Now | After | Why |
| --- | --- | --- | --- | --- |
| 1 | `packages/connection/lib/src/client_viewer.dart` | new | ~50 | item 1: the viewer's stats and a batch with samples |
| 2 | `packages/connection/lib/src/controller_client.dart` | 379 | ~392 | item 1: `viewerStats`, `nowMs`, the `_send` hook, `sendMetrics` |
| 3 | `packages/connection/test/client_view_test.dart` | new | ~150 | item 1's tests |
| 4 | `packages/game_kit/lib/src/hosting_settings.dart` | 40 | ~78 | item 4: `fromEnvironment`, `fromFrameRate`, the define |
| 5 | `packages/game_kit/lib/src/game_session.dart` | 272 | ~274 | item 4: the settings default |
| 6 | `packages/game_kit/test/hosting_settings_test.dart` | new | ~60 | item 4's tests |
| 7 | `packages/connection/bin/sim_token_file.dart` | new | ~50 | item 2: `sim_controller.dart:223-266` moved |
| 8 | `packages/connection/bin/sim_view.dart` | new | ~130 | item 2: the draw-less viewer and its summary |
| 9 | `packages/connection/bin/sim_controller.dart` | 266 | ~246 | item 2: `--view`, the wiring, the summary |
| 10 | `packages/metrics/lib/src/delay_stats.dart` | new | ~45 | item 3: moved out of `session.dart` |
| 11 | `packages/metrics/lib/src/rating_scheduler.dart` | new | ~40 | item 3: moved out of `session.dart` |
| 12 | `packages/metrics/lib/src/host_type.dart` | new | ~12 | item 3: moved out of `session.dart` |
| 13 | `packages/metrics/lib/src/session.dart` | 424 | ~355 | item 3: three types out, the `view` counts in |
| 14 | `packages/metrics/lib/src/report_table.dart` | new | ~140 | item 3: `GroupStats`, `groupBy`, `table`, the new columns |
| 15 | `packages/metrics/lib/src/report.dart` | 351 | ~280 | item 3: `ModeRow`'s seven fields, CSV 26 → 33 |
| 16 | `packages/metrics/lib/metrics.dart` | 12 | 16 | item 3: four export lines |
| 17 | `packages/metrics/test/metrics_test.dart` | 612 | 612 | item 3: 26 → 33, nothing else |
| 18 | `packages/metrics/test/view_report_test.dart` | new | ~120 | item 3's tests |
| 19 | `tv_test_app/lib/src/debug_start.dart` | new | ~70 | item 4: the two defines and the Shape Race start |
| 20 | `tv_test_app/lib/main.dart` | 50 | ~52 | item 4: `home:` |
| 21 | `tv_test_app/test/debug_start_test.dart` | new | ~70 | item 4's tests |
| 22 | `tools/tv-dev.sh` | 108 | ~126 | item 4: `start [--hz] [--game]` |
| 23 | `tools/smoke.sh` | 378 | ~400 | item 5: the `frames` step and `start_tv`'s flags |
| 24 | `docs/dev-tools.md` | 404 | ~416 | the flags, the frames step, the duration |

**Over 300 after, and how they stay there.** `controller_client.dart` ~392: it is the file m12-sessions:69 names;
item 1 keeps everything viewer-shaped in `client_viewer.dart` and adds 13 lines, so it stays under 400 and this is its
last chance to grow — if the review wants more, the next seam is `_parse`-like helpers, which it doesn't have.
`session.dart` ~355 after the three moves; `report.dart` ~280 after `report_table.dart`; the sim's three files are
~246/~130/~50; `smoke.sh` ~400 is a script (the 300/400 rule is for code files, and 378 + 22 is the smallest honest
change — if it must stay under 400, the emulator block `:315-376` moves to `tools/smoke_emulator.sh`, which I'd rather
not do inside this job).

**Order** (each slice leaves the workspace compiling and every check green, `tools/check.sh` names in brackets):
S1 item 1 + 3 [connection] → S2 item 4's game_kit half + 6 [kit] → S3 item 2 [connection] → S4 item 3 [metrics] →
S5 item 4's app and tool half + 21 [tv] → S6 item 5 + 24. Items 1 and 4's game_kit half are independent of s3b G4 and
s3c-a; items 2, 3 and 5 need nothing from them either (the sim and the report read the protocol's fields, which s3a
shipped). The job is gated on s3b G4 and s3c-a only because `FrameView` and the sessions must exist for the tools to
be worth running; the diff itself doesn't touch their files.

## 8. Conflicts with the contract, s3b G4 and s3c-a

1. **`GameSession`'s settings default** (contract §3 writes `this.settings = const HostingSettings()`). A
   range-checked, `kReleaseMode`-aware default can't be const, so the parameter becomes nullable. Question 1.
2. **"Prints a `touch_to_frame` and `frame_jitter` summary at the end" (§6) vs `drain()` emptying itself.** With
   `--metrics --view` the sim's final `drain()` covers only the tail since the last batch. Question 3.
3. **"per controller and in the summary" (item 3).** The report has no per-controller text block today: a controller's
   numbers live on its mode rows (CSV) and in the group tables. I read the item that way; a third table ("By
   controller") would be new output nobody asked for in §6. Question 5.
4. **s3c-a's `FrameView` needs `ControllerClient.nowMs` and a `ViewerStats` from the client**, neither of which exists
   before this job. Item 1 adds both (`nowMs`, `viewerStats`) exactly as that brief names them, so s3c-a's call site is
   `stats: client.viewerStats!` — which is the one place a `!` will appear, and it is proven by the capability the
   screen is only shown for. Question 6.
5. **s3b G4 isn't landed.** The construction sites in §4 are the ones [s3b-g1-plan.md](s3b-g1-plan.md) §2 plans
   (`ArenaSession` in `ArenaView.initState`; `PuzzleSession` in the play view). If s3b G4 builds the session somewhere
   else, only the *place* in §4's second paragraph changes — nothing in this job's diff does, because the rate arrives
   through `GameSession`'s default.
6. **`m12-sessions.md:69`** says `controller_client.dart` is 400 lines and must be split first; it is 379 (s3a G4 split
   it). No extra split is needed or planned.

## 9. Questions

1. **`GameSession`'s const default.** Ok to make `settings` nullable with
   `settings = settings ?? HostingSettings.fromEnvironment()` (a contract deviation in §3's signature), or would you
   rather the rate arrive as an explicit `settings:` argument from the two views (which then need a way to read the
   define themselves, in `test_game` and `puzzle_game`)? *Proposed: the nullable default — one line, and it reaches
   every session built anywhere, including future games.*
2. **The define names.** `FRAME_RATE_HZ` and `START_GAME`, matching `BUILD_NUMBER`/`FIRESTORE_PROJECT` (no prefix)?
   *Proposed: yes. They're read in `game_kit` and `tv_test_app` only; no store build passes them, and release ignores
   both.*
3. **The sim's run summary when `--metrics` is on.** The client drains into every batch, so the sim's final drain is
   only since the last batch. Options: (a) print it as is, with its sample count; (b) add run totals to `ViewerStats`
   (`drain()` also accumulates counts and capped sample lists) so the summary is always the whole run — a small growth
   of a shipped type. *Proposed: (a) — the smoke step runs `--view` without `--metrics`, so its numbers are the whole
   run; (b) only if you want a whole-run figure with both flags on a long run.*
4. **No unit test for `SimView`.** Testing it means a test importing `../bin/sim_view.dart` (nothing in this repo
   imports `bin/` from `test/`). *Proposed: no test; the smoke frames step is its proof, and the arithmetic
   (`ViewerTiming`, `ViewerStats`) already has tests.*
5. **"Per controller" in item 3.** *Proposed: the seven values on each mode row in the CSV (a controller's rows) plus
   the three compact columns in both group tables (the summary) — no new table. Say if you meant a per-controller text
   block in `report()`.*
6. **`client.viewerStats!` in s3c-a.** *Proposed: keep the `!` in `FrameView`'s call site (the screen is only shown for
   a phone that listed `view`), or have `FrameView` take the `ControllerClient` and read it once with an
   `ArgumentError`, as `SimView.of` does. I'd match `SimView.of` (no `!` in shipped code).*
7. **The `frames` step restarts the TV app, and skips when it didn't start it.** *Proposed: as written (§5) — a
   restart ends pairings and truncates the log, and killing a copy the developer had open breaks smoke's own rule
   (`smoke.sh:229-232`).*
8. **`smoke.sh` at ~400 lines.** *Proposed: accept ~400 (a script; 378 + 22), or move the emulator block
   (`:315-376`, ~60 lines) to `tools/smoke_emulator.sh` in a later tools job — not inside this one.*
