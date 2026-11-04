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
}
