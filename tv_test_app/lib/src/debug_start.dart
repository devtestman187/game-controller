import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// The game a debug build starts in, from `--dart-define=START_GAME=…`:
/// `arena` or `shape_race`. `tools/tv-dev.sh start --game` sets it, and its
/// `--hz` sets the matching `FRAME_RATE_HZ` (M12 §6).
///
/// Unset or anything else starts at the home screen. Release builds ignore
/// both.
const String startGame = String.fromEnvironment('START_GAME');

/// The screen the app starts on (M12 §6): the game [game] names, skipping the
/// menus so `tools/tv-dev.sh` and `tools/smoke.sh` can measure a game without
/// a phone pressing through them. Null for the home screen: no game named, or
/// a release build.
Widget? debugStartScreen(String game) {
  if (!kDebugMode) return null;
  return switch (game) {
    'arena' => const GameScreen(),
    'shape_race' => const _ShapeRaceStart(),
    _ => null,
  };
}

/// Shape Race's first Easy puzzle with one team, whoever connected first: the
/// join screen and the puzzle picker are what a measuring run skips.
class _ShapeRaceStart extends ConsumerWidget {
  const _ShapeRaceStart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The home screen kept these going (home_screen.dart): without them the
    // games would be silent and the screen could sleep.
    ref.watch(keepAwakeProvider);
    ref.watch(gameSoundsProvider);
    final players = ref.watch(gamePlayersProvider);
    final puzzle = ref.watch(puzzleLibraryProvider).value?.ofLevel(Level.easy).firstOrNull;
    if (players.isEmpty || puzzle == null) return const _WaitingForController();
    return PuzzleScreen(
      choice: PuzzleChoice(level: Level.easy, puzzleId: puzzle.id),
      teams: {players.first.id: PuzzleSide.left},
    );
  }
}

/// What the app shows until a phone pairs: the arena's own words on a screen
/// of its own (game_screen.dart shows them while nobody is connected).
class _WaitingForController extends StatelessWidget {
  const _WaitingForController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Waiting for a controller…', style: Theme.of(context).textTheme.headlineSmall)),
    );
  }
}
