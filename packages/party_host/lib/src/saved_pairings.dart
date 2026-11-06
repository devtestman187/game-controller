import 'package:connection/connection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The pairings saved by [savePairings]. Broken entries are skipped, so a
/// phone whose token went bad is asked for the code again instead of the
/// whole list being lost.
List<SavedPairing> loadPairings(SharedPreferences prefs) => throw UnimplementedError();

/// Saves [pairings], so phones reconnect without a code after the host app
/// restarts (PRD T5).
void savePairings(SharedPreferences prefs, List<SavedPairing> pairings) => throw UnimplementedError();
