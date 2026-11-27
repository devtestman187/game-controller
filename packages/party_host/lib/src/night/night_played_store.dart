import 'dart:async';
import 'dart:convert';

import 'package:puzzle_game/puzzle_game.dart' show Level;
import 'package:shared_preferences/shared_preferences.dart';

import 'variant.dart';

/// Saves and loads the variants a night has played on the host's prefs (JSON list of variant ids under [_key]), so a
/// night restored after a restart keeps its played list.
final class NightPlayedStore {
  const NightPlayedStore(this._prefs);

  /// The prefs key the played list is kept under.
  static const _key = 'party_night_played_v1';

  final SharedPreferences _prefs;

  /// The saved ids that are still launch variants, in the order they were played. An id that is unknown or not text
  /// is dropped; a save that is not JSON at all is removed and gives an empty list. Never throws.
  List<String> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    final decoded = _decode(raw);
    if (decoded is! List<Object?>) {
      unawaited(_prefs.remove(_key));
      return const [];
    }
    // A variant's id does not depend on its tier, so any tier gives the same known ids.
    final known = {for (final variant in launchVariants((_) => Level.easy)) variant.id};
    return [
      for (final id in decoded)
        if (id is String && known.contains(id)) id,
    ];
  }

  /// Saves [ids] in place of any saved ones.
  Future<void> save(List<String> ids) async {
    await _prefs.setString(_key, jsonEncode(ids));
  }

  /// Removes the saved list, when the night it belongs to ends.
  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  /// The JSON in [raw], or null when it is not JSON at all.
  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
