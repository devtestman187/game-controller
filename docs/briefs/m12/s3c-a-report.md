# s3c-a report — FrameView (game_kit), G2 → G4

Job: `docs/briefs/m12/s3c-a.md`. The contract implemented is `docs/design/m12-sessions.md` §4 as the brief
restates it: only `FrameView`, `updateAppText` and their tests. No client wiring, no phone app change, no tools.

## Files changed

- `packages/game_kit/lib/src/frame_view.dart` (new, 218 lines) — `updateAppText` and `FrameView` as the brief's
  contract: subscribes to `Stream<ViewEvent>`, draws `SizedBox.shrink()` before a start and after an end, shows
  `updateAppText` for an unknown module / a snapshot version mismatch / a `createViewer` `FormatException`,
  otherwise resets `ViewerTiming(hz: start.hz, maxPlayoutFrames: settings.maxPlayoutFrames)`, `stats` and a
  `PlayoutBuffer`, buffers `ViewFrame`s (jitter → `frameArrived` → `decode`, `FormatException` drops that frame),
  and runs a Ticker only while a viewer is active: each tick picks `a`/`b`/`t` from `timing.renderAtMs(nowMs())`
  and draws `a.snapshot`, or `a.snapshot.lerpTo(b.snapshot, t)`, through `viewer.build(..., (roster:
  a.frame.roster, playerId: playerId))`. The first tick that draws a given `a` reports `stats.frameDrawn` from a
  post-frame callback, once per `a`. `didUpdateWidget` resubscribes on a new `views` stream; `dispose` cancels
  the subscription and the Ticker. A tick that would draw the same `a`, `b` and `t` returns without `setState`.
- `packages/game_kit/lib/game_kit.dart` — one line added: `export 'src/frame_view.dart';`.
- `packages/game_kit/pubspec.yaml` — `test_game` added to `dev_dependencies` (path), for the real-Arena-frame test.
- `packages/game_kit/test/support/fake_view.dart` (new, 73 lines) — the fake module for the viewer tests:
  `DotSnapshot` (one double `x`, `lerpTo` lerps it, version 3), `DotModule` (id `dot`, `createViewer` throws
  `FormatException('start')` unless `setup['start']` is a num), `DotViewer` (validates `v` and `x`), and
  `DotDraw`, the drawn widget a test reads the snapshot and `ViewContext` off.
- `packages/game_kit/test/frame_view_test.dart` (new, 264 lines) — 9 widget tests with a fake phone clock.

`pubspec.lock` is unchanged: `test_game` was already a workspace member, so the lock says nothing new.
`flutter pub get` ran at the repository root after the pubspec change and succeeded (pub accepts the
dev-dependency cycle `game_kit` → `test_game` → `game_kit`).

## Tests and the values they check

1. *nothing is drawn before a start, and a frame before one is ignored* — no `DotDraw` and no update text before
   any start; a frame at `at` 1000 then a tick: still nothing, `drain().view.frames == 0`, `stages` empty (no
   `frame_jitter` either, so the frame never reached the timing).
2. *an unknown game, a newer version and a bad setup say update the app, and a good start draws* — starts with
   `game: 'puzzle'` (no module), `sv: 4` (module says 3) and `setup: {}` each show `updateAppText`; a frame sent
   while the text is shown draws nothing; a good start clears the text, draws nothing until the first frame, then
   draws `x = 0.5`.
3. *one frame is drawn, and the view never runs past the newest* — one frame at `at` 1000 with `x = 0.25` draws
   0.25; 1000 ms later (phone clock 2000, so `r = 2000`, past the newest) still 0.25.
4. *two frames 16 ms apart are drawn halfway at a render time halfway between them* — frames at 1000 (`x` 0.2)
   and 1016 (`x` 0.6), arrivals equal to `at`, so skews 0 and 0: `base = 0`, lateness `[0, 0]`, nearest rank
   `ceil(95 × 2 / 100) − 1 = 1` → `playoutDelayMs = 0`; at phone clock 1008, `r = 1008`, `t = (1008 − 1000) / 16
   = 0.5`, drawn `x = 0.2 + (0.6 − 0.2) × 0.5 = 0.4`. `frame_jitter` samples `[0, 0]`.
5. *a drawn frame is measured once, however many ticks draw it* — frames at 1000 / 1016 / 1032 (`x` 0, 0.25,
   0.5) and 20 ticks of 16 ms: `drain().view.frames == 3` (one per new `a`, none for the repeated ticks on the
   newest), and the final drawn `x` is 0.5 (the newest frame, `b` null).
6. *touch_to_frame is the draw time minus the send time of the input the frame acks* — `inputSent(5, 1000)`
   after the start (see the question below), frame `n = 1` at 1016 with `acks {'p1': 5}` drawn at 1016 →
   sample `1016 − 1000 = 16`. Also checks `ViewContext`: `playerId == 'p1'` and the roster is the frame's.
7. *a view end clears the screen, and later frames are ignored* — one frame drawn (1 frame drained before the
   end), `ViewEnded` clears the widget; a later frame at 1016 and two ticks record nothing: `frames == 0`,
   `stages` empty.
8. *a new views stream replaces the old one* — after `pumpWidget` with a second stream, an event on the first
   stream draws nothing and one on the second draws; after `pumpWidget(SizedBox)` the second stream's event
   records nothing, so `dispose` cancelled the subscription and the Ticker (every test unloads the view, so
   `flutter_test` would also fail on a Ticker left active).
9. *a real arenaModule frame draws without throwing* — `GameRegistry([arenaModule])`, a `view_start` with
   `arenaModule.id` / `arenaModule.snapshotVersion` / `arenaSetup`, and a frame whose snapshot is a real
   `ArenaSnapshot(...).toJson()` (one player, one goal). The arena's `CustomPaint` (`Key('arena')`) is found.

Test plumbing worth knowing: a stream event added just before `tester.pump()` is delivered at the end of that
pump, so `send()` pumps twice (deliver, then draw). The phone clock is the test's own `Clock`, never real time.

## Checks

- `tools/check.sh format analyze kit` — **PASS, PASS, PASS** (`kit`: 25 tests, 9 of them new).
- `tools/review.sh` (mechanical checks on the diff) — `0 fail, 0 note`.
- `flutter pub get` at the root — succeeded.

Sizes: `frame_view.dart` 218 lines (limit 250), `frame_view_test.dart` 264 (limit 500), `fake_view.dart` 73.

## Questions and suggestions

1. `stats.reset(hz: start.hz)` runs only on a start the app *can* show, as the behaviour list puts it ("Otherwise
   resets …"). A start it can't show leaves the previous game's numbers in `ViewerStats` until the next valid
   start; frames are ignored, so nothing new is recorded. Say if the reset should also happen for a start that
   shows `updateAppText`.
2. `updateAppText` is drawn as a bare `Text`; centring and padding are left to the phone screen that puts
   `FrameView` in place. If it should be centred by the view itself, that's a small change here.
3. `didUpdateWidget` only resubscribes, as the brief says; it doesn't reset the game, timing or buffer. A phone
   app that swaps in a new client's stream while a game is drawn keeps drawing it until the new stream's
   `view_start`. Confirm that's intended.
4. A `decode` `FormatException` drops the frame with a comment but no log: `FrameView` has no `LogSink`. If the
   drop should be observable (a debug counter for Diagnostics), an injected sink or observer would be needed.
5. The real-module test needs `test_game` as a dev dependency of `game_kit`, which makes a dev-dependency cycle
   (`test_game` depends on `game_kit`). `pub get` accepts it; if the cycle is unwanted, the arena test goes and
   the fake module covers the rest, as the brief allows.

## Commit message

```
Add FrameView: phones draw a hosted game smoothly (m12 §4)

FrameView buffers a client's view events, draws them through ViewerTiming
on a Ticker, and measures them in ViewerStats. Nothing before a view_start;
an unknown module, a newer snapshot version or a bad setup shows
updateAppText instead. The first draw of each frame is measured once, in a
post-frame callback, for touch_to_frame. A new views stream resubscribes;
dispose stops the subscription and the Ticker.

9 widget tests with a fake dot module and a fake clock, and one with a real
Arena module frame (test_game is a dev dependency for it).
```

## Status row

s3c-a G4 done: `FrameView` + `updateAppText` in game_kit (218 lines) with 9 widget tests; format, analyze and kit
pass, review 0 fail. Open: the rest of s3c — the tools/report/smoke steps, the debug frame-rate option, and the
PC measurement.

## Delete

- none
