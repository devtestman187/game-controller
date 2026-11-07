job: m12 step3 s3c-a G4 — FrameView (game_kit)
stop: after G4 (small job: G2 → G4 in one go). Only FrameView and its tests. No client wiring, no phone app change, no tools.
read: docs/design/m12-sessions.md §4 (the contract; it wins) · docs/coding-guidelines.md · packages/game_kit (lib, test) · packages/connection/lib/src/{viewer_timing,viewer_stats,client_controls}.dart · packages/test_game/lib/src/arena_module.dart (a real module, for one test)

contract (lib/src/frame_view.dart, exported from game_kit.dart):
```dart
/// Draws the game a host shows (m12 §4): buffers its frames, draws them
/// smoothly through ViewerTiming, and measures them in [stats].
class FrameView extends StatefulWidget {
  const FrameView({required this.views, required this.registry, required this.stats, required this.nowMs, this.playerId, this.settings = HostingSettings.defaults, super.key});
  final Stream<ViewEvent> views;      // ControllerClient.view
  final GameRegistry registry;
  final ViewerStats stats;            // the client's; FrameView resets it on view_start and records into it
  final int Function() nowMs;         // the same clock as ViewFrame.arrivedAtMs (ControllerClient.nowMs)
  final String? playerId;             // this phone's player, for acks and ViewContext
  final HostingSettings settings;     // maxPlayoutFrames
}
```

behaviour:
- Before a `ViewStarted`, and after a `ViewEnded`: draws `SizedBox.shrink()`; frames are ignored.
- `ViewStarted`: module = `registry.moduleFor(start.game)`. Unknown module, `start.snapshotVersion != module.snapshotVersion`, or `createViewer` throwing `FormatException` → draws the text "Update the app to see this game" (one const string, exported as `updateAppText`) and ignores frames until the next start. Otherwise resets `ViewerTiming(hz: start.hz, maxPlayoutFrames: settings.maxPlayoutFrames)`, `stats.reset(hz: start.hz)`, the `PlayoutBuffer`, and draws nothing until the first frame.
- `ViewFrame`: `jitter = timing.addFrame(atMs: frame.atMs, arrivedAtMs: arrivedAtMs)`, `stats.frameArrived(frame.n, jitterMs: jitter)`, `viewer.decode(frame.snapshot)` (a `FormatException` drops that frame only) and `buffer.add((frame, snapshot), frame.atMs)`.
- A Ticker runs only while a viewer is active. Each tick: `r = timing.renderAtMs(nowMs())`, `pick = buffer.pick(r)`; draw `a.snapshot` when `b` is null, else `a.snapshot.lerpTo(b.snapshot, t)`, through `viewer.build(context, snapshot, (roster: a.frame.roster, playerId: playerId))`.
- After the Flutter frame that first draws a given `a` (post-frame callback): `stats.frameDrawn(playerId == null ? null : a.frame.acks[playerId], nowMs())`. Once per frame `a`, not per tick.
- A new `views` stream in `didUpdateWidget` resubscribes; dispose cancels the subscription and the Ticker.
- No `setState` while nothing changed and no viewer is active.

tests (test/frame_view_test.dart, a fake module in test/support with a snapshot holding one double `x` whose lerpTo lerps it; a fake clock):
- nothing drawn before a start; a frame before a start is ignored (no stats change).
- unknown module → update text; version mismatch → update text; setup FormatException → update text; a later good start draws.
- one frame then ticks: draws `x` of that frame; never extrapolates past the newest.
- two frames 16 ms apart, steady arrivals (delay 0): at a render time halfway, `x` is the midpoint.
- frameDrawn once per new `a`: 3 frames, 20 ticks → `stats.drain().view.frames == 3`; touch_to_frame recorded from `stats.inputSent(5, t0)` and a frame acking 5 for `playerId` drawn at t1 → sample `t1 − t0`.
- view_end → nothing drawn, later frames ignored.
- a real `arenaModule` frame (an `ArenaSnapshot` JSON) draws without throwing.

rules: frame_view.dart ≤ 250; tests ≤ 500; no change to connection, test_game or puzzle_game; no change to the existing game_kit files except the export line · tools/review.sh: no FAIL on your lines. A dev_dependency on test_game is fine for the real-module test; if it makes a cycle, use the fake module only and say so.
allow: packages/game_kit
pub: yes
check: format analyze kit
report: docs/briefs/m12/s3c-a-report.md
