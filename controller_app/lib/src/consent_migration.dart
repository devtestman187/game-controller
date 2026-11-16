import 'package:party_host/party_host.dart' show statsConsentKey;
import 'package:shared_preferences/shared_preferences.dart';

/// The preference that held this phone's stats answer before the app asked its
/// own two questions (design sentry-consent.md): "Share control stats with the
/// TV", saved only when the adult changed it.
const legacyShareStatsKey = 'shareStats';

/// Carries an older build's stats answer over to today's question (design
/// sentry-consent.md): when the stats question has never been answered
/// ([statsConsentKey] absent) and the older build saved an explicit answer,
/// that answer is this phone's answer. A phone that never touched the setting
/// saved nothing, so it is asked like a new one, as the older build's answer
/// was "on" only as a default.
///
/// Returns whether it carried an answer over.
Future<bool> migrateLegacyStats(SharedPreferences prefs) async {
  if (prefs.containsKey(statsConsentKey)) return false;
  final legacy = prefs.getBool(legacyShareStatsKey);
  if (legacy == null) return false;
  await prefs.setBool(statsConsentKey, legacy);
  return true;
}
