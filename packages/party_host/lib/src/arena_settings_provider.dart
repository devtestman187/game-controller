import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_game/test_game.dart';

import 'prefs.dart';

/// The Arena's own library of maps, loaded from the level kit's data files
/// (M14 k1b): the waiting card shows them and a round plays the one it picks
/// (M14 b2). A provider so a test can hand in the maps read from the files,
/// as the puzzles are.
final arenaMapLibraryProvider = FutureProvider<ArenaMapLibrary>((ref) => ArenaMapLibrary.load());

/// The Arena's settings, saved on the host (M14 b2, design sections 7b and 8):
/// the mode the waiting card opens on, the map it has picked (null: Surprise
/// me), Robo's level, and the map the last round played, so Surprise me picks
/// another one.
///
/// The mode and Robo's level are the host's own: the night always plays the
/// Bumper Round, so its waiting card offers that alone. The map the last round
/// played is what keeps two rounds from repeating a map until the night's own
/// "a map it hasn't used yet" (design section 7b) has a night to ask.
final class ArenaSettings {
  const ArenaSettings({this.mode = ArenaMode.bumper, this.mapId, this.roboLevel = RoboLevel.easy, this.lastMapId});

  /// What a host that has saved none plays with: the Bumper Round on a surprise
  /// map, with Robo on Easy the first time (design section 7a). The waiting card
  /// opens as the mock-up draws it (frame 8): Bumper chosen, every map offered.
  static const defaults = ArenaSettings();

  /// The mode the waiting card opens on, and the round plays.
  final ArenaMode mode;

  /// The map the waiting card has picked, or null for Surprise me.
  final String? mapId;

  /// Robo's level while Robo is in (design section 7a).
  final RoboLevel roboLevel;

  /// The map the last round started on, or null before the first.
  final String? lastMapId;

  /// Whether the waiting card plays on a surprise map.
  bool get surprise => mapId == null;

  ArenaSettings copyWith({ArenaMode? mode, RoboLevel? roboLevel, String? lastMapId}) => ArenaSettings(
    mode: mode ?? this.mode,
    mapId: mapId,
    roboLevel: roboLevel ?? this.roboLevel,
    lastMapId: lastMapId ?? this.lastMapId,
  );

  /// These settings picking [mapId], or Surprise me with null.
  ArenaSettings withMap(String? mapId) =>
      ArenaSettings(mode: mode, mapId: mapId, roboLevel: roboLevel, lastMapId: lastMapId);

  /// The settings as the host saves them: the mode, the map, Robo's level and
  /// the last map's id. A surprise map is saved as no id, so a host that saved
  /// one starts on Surprise me again.
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (mapId != null) 'map': mapId,
    'robo': roboLevel.name,
    if (lastMapId != null) 'last': lastMapId,
  };

  /// The settings [json] holds; a field this build doesn't know is its default.
  static ArenaSettings fromJson(Object? json) {
    if (json is! Map) return defaults;
    return ArenaSettings(
      mode: json['mode'] == ArenaMode.bumper.name ? ArenaMode.bumper : ArenaMode.race,
      mapId: json['map'] is String ? json['map'] as String : null,
      roboLevel: roboLevelOf(json['robo']) ?? RoboLevel.easy,
      lastMapId: json['last'] is String ? json['last'] as String : null,
    );
  }
}

/// The Arena's settings, saved on the host like the puzzle's.
final arenaSettingsProvider = NotifierProvider<ArenaSettingsNotifier, ArenaSettings>(ArenaSettingsNotifier.new);

/// Saves the Arena's settings and the map each round starts on.
class ArenaSettingsNotifier extends Notifier<ArenaSettings> {
  static const _key = 'arenaSettings';

  @override
  ArenaSettings build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return ArenaSettings.defaults;
    try {
      return ArenaSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return ArenaSettings.defaults;
    }
  }

  /// Picks the mode the waiting card offers, and the next round plays.
  void setMode(ArenaMode mode) => _save(state.copyWith(mode: mode));

  /// Picks a map, or Surprise me with null.
  void setMap(String? mapId) => _save(state.withMap(mapId));

  /// Picks Robo's level (design section 7a).
  void setRoboLevel(RoboLevel level) => _save(state.copyWith(roboLevel: level));

  /// Notes the map a round started on, so Surprise me picks another next time.
  void playedMap(String mapId) => _save(state.copyWith(lastMapId: mapId));

  void _save(ArenaSettings settings) {
    state = settings;
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(settings.toJson())));
  }
}
