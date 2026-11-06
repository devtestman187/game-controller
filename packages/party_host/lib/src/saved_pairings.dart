import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pairingsKey = 'pairings';

/// The pairings saved by [savePairings]. Broken entries are skipped, so a
/// phone whose token went bad is asked for the code again instead of the
/// whole list being lost.
List<SavedPairing> loadPairings(SharedPreferences prefs) {
  final raw = prefs.getString(_pairingsKey);
  if (raw == null) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [for (final item in list) ?SavedPairing.fromJson(item)];
  } catch (_) {
    return const [];
  }
}

/// Saves [pairings], so phones reconnect without a code after the host app
/// restarts (PRD T5).
void savePairings(SharedPreferences prefs, List<SavedPairing> pairings) =>
    prefs.setString(_pairingsKey, jsonEncode([for (final p in pairings) p.toJson()]));
