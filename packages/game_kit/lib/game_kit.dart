/// The host's game loop (m12 §3, §4): a game runs in fixed 1/60 s steps
/// inside a [GameSession], which sends frames to the controllers showing it,
/// and a viewer draws a game through a [GameModule]. A round's result, which
/// each game's screen will hand on, is a [RoundResult] (M14).
///
/// The level kit (M14 k1a) is here too, shared by both games: a [LevelIssue]
/// either game's rule book returns, the file header and index check every
/// level keeps, and the [JsonSchema] a schema file is checked with.
library;

export 'src/frame_view.dart';
export 'src/game_module.dart';
export 'src/game_registry.dart';
export 'src/game_session.dart';
export 'src/hosting_settings.dart';
export 'src/level/json_schema.dart';
export 'src/level/level_files.dart';
export 'src/level/level_header.dart';
export 'src/level/level_issue.dart';
export 'src/round_result.dart';
