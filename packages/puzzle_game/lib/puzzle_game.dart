/// Shape Race, the puzzle game (PRD v2 M10): puzzle data ([Puzzle],
/// [PuzzleLibrary]), the rules ([PuzzleGame] for a side, [PuzzleMatch] for 1 to
/// 4 players; they never draw), snapshots
/// ([PuzzleSnapshot], S8) and the view ([PuzzleView]), which draws only from
/// a snapshot into the box it's given (S4).
library;

export 'src/game.dart';
export 'src/library.dart';
export 'src/match.dart';
export 'src/puzzle.dart';
export 'src/settings.dart';
export 'src/snapshot.dart';
export 'src/play_view.dart';
export 'src/view.dart';
