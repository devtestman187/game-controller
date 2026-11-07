import 'package:flutter/widgets.dart';
import 'package:game_kit/game_kit.dart';

import 'library.dart';
import 'match.dart';
import 'puzzle.dart';
import 'snapshot.dart';
import 'view.dart';

/// The Shape Race viewer setup (m12 §4): the puzzle to draw, its level, the
/// clock the bar fills against, and who plays on which side.
Map<String, Object?> shapeRaceSetup(PuzzleMatch match) => {
  'puzzle': match.puzzle.id,
  'level': match.puzzle.level.name,
  'timeLimitS': match.sides.first.game.settings.timeLimitS,
  'teams': {for (final MapEntry(key: id, value: side) in match.teams.entries) id: side.name},
};

/// Shape Race as a viewer draws it (m12 §4): frames of [MatchSnapshot], drawn
/// from the shared puzzle files.
final class ShapeRaceModule implements GameModule {
  const ShapeRaceModule();

  @override
  String get id => 'shape_race';

  @override
  int get snapshotVersion => MatchSnapshot.version;

  /// A viewer for the setup's puzzle. Every key is checked and named when it
  /// doesn't fit; a puzzle ID this app version doesn't have isn't an error,
  /// because every app version has its own copy of the files (Q1).
  @override
  GameViewer createViewer(Map<String, Object?> setup) {
    final puzzleId = _field<String>(setup, 'puzzle');
    _field<String>(setup, 'level');
    final timeLimitS = _field<int>(setup, 'timeLimitS');
    final teams = _field<Map<String, Object?>>(setup, 'teams');
    for (final MapEntry(:key, :value) in teams.entries) {
      if (value is! String) {
        throw FormatException('view setup "teams": $key has ${value.runtimeType} instead of a side name');
      }
    }
    return ShapeRaceViewer(puzzleId: puzzleId, timeLimitS: timeLimitS);
  }
}

/// The one Shape Race module the apps put in their registry (m12 §0).
const shapeRaceModule = ShapeRaceModule();

/// [setup]'s [key], or a [FormatException] naming the key when it is missing
/// or of another type.
T _field<T>(Map<String, Object?> setup, String key) {
  final value = setup[key];
  if (value is T) return value;
  throw value == null
      ? FormatException('view setup "$key" is missing')
      : FormatException('view setup "$key": ${value.runtimeType} is not $T');
}

/// Draws a match on a phone showing the game: the same board (or split
/// screen) the TV draws, from the frames' [MatchSnapshot] (S8).
final class ShapeRaceViewer implements GameViewer {
  const ShapeRaceViewer({required this.puzzleId, required this.timeLimitS});

  /// The puzzle the frames draw, found by ID in the shared files.
  final String puzzleId;

  /// What the clock bar fills against: the time limit the match started with
  /// (m12 §4, Q2).
  final int timeLimitS;

  @override
  GameSnapshot decode(Map<String, Object?> json) => MatchSnapshot.fromJson(json);

  @override
  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view) {
    if (snapshot is! MatchSnapshot) {
      throw ArgumentError.value(snapshot, 'snapshot', 'The Shape Race viewer draws MatchSnapshot frames');
    }
    return _LoadedPuzzle(
      puzzleId: puzzleId,
      builder: (puzzle) => MatchView(puzzle: puzzle, snapshot: snapshot, timeLimitS: timeLimitS),
    );
  }
}

/// One load of the shared puzzle files, started by the first viewer to draw
/// and shared by every viewer after it (Q1): a phone builds one viewer per
/// game, and the files don't change while the app runs.
Future<PuzzleLibrary>? _puzzleLoad;

/// Draws the match with the setup's puzzle once the files load: nothing until
/// then, and [updateAppText] when this app version has no
/// such puzzle (or never loaded its files).
class _LoadedPuzzle extends StatelessWidget {
  const _LoadedPuzzle({required this.puzzleId, required this.builder});

  final String puzzleId;
  final Widget Function(Puzzle puzzle) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<PuzzleLibrary>(
    future: _puzzleLoad ??= PuzzleLibrary.load(),
    builder: (context, loaded) {
      final puzzle = loaded.data?.byId(puzzleId);
      if (puzzle != null) return builder(puzzle);
      if (loaded.connectionState != ConnectionState.done) return const SizedBox.shrink();
      return const Center(child: Text(updateAppText));
    },
  );
}
