import 'package:controller/src/consent_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An older build's stats answer becomes this phone's answer to the usage stats
/// question (design sentry-consent.md): carried over only when the question is
/// unanswered, and only when the older build saved an explicit answer.
void main() {
  /// The preferences saved before a launch, as the app finds them at startup.
  Future<SharedPreferences> saved(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('a phone that never touched the old setting is asked, like a new one', () async {
    final prefs = await saved({});
    expect(await migrateLegacyStats(prefs), isFalse);
    expect(prefs.getBool('statsConsent'), isNull, reason: 'only an explicit old answer carries over');
  });

  test('an older build\'s "don\'t share" is this phone\'s no', () async {
    final prefs = await saved({legacyShareStatsKey: false});
    expect(await migrateLegacyStats(prefs), isTrue);
    expect(prefs.getBool('statsConsent'), isFalse);
  });

  test('an older build\'s "share" is this phone\'s yes', () async {
    final prefs = await saved({legacyShareStatsKey: true});
    expect(await migrateLegacyStats(prefs), isTrue);
    expect(prefs.getBool('statsConsent'), isTrue);
  });

  test('an answered phone keeps its answer, whatever the old setting says', () async {
    final prefs = await saved({'statsConsent': false, legacyShareStatsKey: true});
    expect(await migrateLegacyStats(prefs), isFalse, reason: 'answered already: nothing to carry over');
    expect(prefs.getBool('statsConsent'), isFalse);
  });

  test('a second launch changes nothing', () async {
    final prefs = await saved({legacyShareStatsKey: true});
    expect(await migrateLegacyStats(prefs), isTrue);
    expect(await migrateLegacyStats(prefs), isFalse);
    expect(prefs.getBool('statsConsent'), isTrue);
  });
}
