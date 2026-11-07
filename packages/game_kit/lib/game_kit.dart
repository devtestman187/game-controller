/// The host's game loop (m12 §3, §4): a game runs in fixed 1/60 s steps
/// inside a [GameSession], which sends frames to the controllers showing it,
/// and a viewer draws a game through a [GameModule].
library;

export 'src/game_module.dart';
export 'src/game_registry.dart';
export 'src/game_session.dart';
export 'src/hosting_settings.dart';
