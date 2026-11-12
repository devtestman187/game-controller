import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

/// A game started without a person pressing through the menus (M15 a2): what
/// `POST game/start` asks for, and what the debug start define asks for. One
/// type, so both go through one screen ([AutomationGameScreen]).
///
/// The arena's map and Robo's level are its saved settings, applied before
/// the screen opens; a field here that a game doesn't have is refused when
/// the request is read.
final class AutomationGameStart {
  const AutomationGameStart({
    required this.game,
    this.mode,
    this.mapId,
    this.puzzleId,
    this.level,
    this.teams = const {},
  });

  /// The arena's id on the wire (`arena`, as its records name it).
  static const arena = 'arena';

  /// Shape Race's id on the wire (`shape_race`, as `START_GAME` named it).
  static const shapeRace = 'shape_race';

  /// The games a launch may start.
  static const games = [arena, shapeRace];

  /// The game [name] starts, whichever of [games] it is; null for anything
  /// else, so an unknown define starts at the home screen.
  static AutomationGameStart? ofName(String name) => games.contains(name) ? AutomationGameStart(game: name) : null;

  /// The game to run: one of [games].
  final String game;

  /// The arena's mode (its saved setting when null).
  final ArenaMode? mode;

  /// The arena's map id, or null for Surprise me.
  final String? mapId;

  /// The puzzle to play, by id; null asks for the first of [level].
  final String? puzzleId;

  /// The puzzle's level; null is Easy, as the debug start always was.
  final Level? level;

  /// Each side of the puzzle, by player number; empty gives the first player
  /// the left board, as the debug start always did.
  final Map<int, PuzzleSide> teams;

  /// What the automation's `status` reports about the round this start runs.
  Map<String, Object?> describe() => {
    'game': game,
    if (mode != null) 'mode': mode!.name,
    if (mapId != null) 'map': mapId,
    if (puzzleId != null) 'puzzle': puzzleId,
    if (level != null) 'level': level!.name,
    if (teams.isNotEmpty) 'teams': {for (final MapEntry(:key, :value) in teams.entries) '$key': value.name},
  };
}
