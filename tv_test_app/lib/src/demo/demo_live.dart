import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

/// The game objects the views are running right now, for the demo director
/// (docs/demo-video-runbook.md 2.2). Only ever read or written when
/// [installDemoLive] has run, which only a build made with
/// `--dart-define=DEMO_DIRECTOR=true` does; in every other build the views'
/// hooks stay null and nothing here is touched.
final class DemoLive {
  DemoLive._();

  static final DemoLive instance = DemoLive._();

  /// The Shape Race match on screen, or null when no game is playing.
  PuzzleMatch? match;

  /// The Arena game on screen, or null when no game is playing.
  ArenaGame? arena;

  /// The TV route on top, as [reportScreen] last saw it. The director writes
  /// it as the scene's first `screen` event, so a take's log starts from the
  /// screen it was recorded on even when the showrunner navigated before it.
  String currentScreen = 'home';

  /// Sends one event to the director. Null unless [installDemoLive] ran and a
  /// director is listening, which only a DEMO_DIRECTOR build ever does.
  void Function(String name, [Map<String, Object?>? data])? onEvent;

  /// The running match's own events (pickup, snap, wrong, help, finished),
  /// for the take's log. Null unless a director is listening.
  void Function(PuzzleSide side, PuzzleEvent event)? onPuzzleEvent;

  /// Logs one event through [onEvent]; nothing in a normal build.
  void reportEvent(String name, [Map<String, Object?>? data]) => onEvent?.call(name, data);

  /// Logs one of the match's events through [onPuzzleEvent].
  void reportPuzzleEvent(PuzzleSide side, PuzzleEvent event) => onPuzzleEvent?.call(side, event);

  /// Logs a route change as a `screen` event (docs/demo-video-runbook.md 2.8
  /// step 3: R1 needs home, games, puzzle list, join).
  void reportScreen(String name) {
    currentScreen = name;
    reportEvent('screen', {'screen': name});
  }
}

/// Points the two views' demo hooks at [DemoLive]. Call once in `main()`,
/// before `runApp`, when `demoDirector` is true.
void installDemoLive() {
  onPuzzleMatchCreated = (match) => DemoLive.instance.match = match;
  onPuzzleMatchDisposed = (match) {
    if (identical(DemoLive.instance.match, match)) DemoLive.instance.match = null;
  };
  onArenaGameCreated = (arena) => DemoLive.instance.arena = arena;
  onArenaGameDisposed = (arena) {
    if (identical(DemoLive.instance.arena, arena)) DemoLive.instance.arena = null;
  };
  onPuzzleMatchEvent = (side, event) => DemoLive.instance.reportPuzzleEvent(side, event);
}
