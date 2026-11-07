import 'game_module.dart';

/// Every game a viewer can draw, by module ID (m12 §0, conflicts 1 and 7).
///
/// The games' packages export their modules and the apps build the registry
/// (`GameRegistry([shapeRaceModule, arenaModule])`), so `game_kit` never
/// depends on a game.
final class GameRegistry {
  GameRegistry([List<GameModule> modules = const []]) {
    for (final module in modules) {
      if (_modules.containsKey(module.id)) {
        throw ArgumentError.value(module.id, 'modules', 'Two game modules have the same ID');
      }
      _modules[module.id] = module;
    }
  }

  final _modules = <String, GameModule>{};

  /// The module with [id], or null when this app version doesn't know it.
  GameModule? moduleFor(String id) => _modules[id];
}
