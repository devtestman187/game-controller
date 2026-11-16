import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// The Settings' two consent switches (design sentry-consent.md): the control
/// stats one, which every phone has, and the crash reports one, which only a
/// build that could send a report shows. Both record this phone's answer.
void main() {
  testWidgets('the stats switch is off until the adult answers, and records the answer', (tester) async {
    final app = await pumpApp(tester, paired: true);
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsShareStats')));
    expect(_switch(tester, 'settingsShareStats').value, isFalse, reason: 'nothing is shared before an answer');
    expect(app.prefs.getBool('statsConsent'), isNull);

    await tester.tap(find.byKey(const Key('settingsShareStats')));
    await settle(tester);
    expect(_switch(tester, 'settingsShareStats').value, isTrue);
    expect(app.prefs.getBool('statsConsent'), isTrue, reason: 'the switch is this phone\'s stats answer');
  });

  testWidgets('a build with no Sentry project shows no crash reports switch', (tester) async {
    await pumpApp(tester, paired: true);
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsShareStats')));
    expect(find.byKey(const Key('settingsCrashReports')), findsNothing);
  });

  testWidgets('the crash switch records the answer and turns reports on and off at once', (tester) async {
    final reports = _Reports();
    final app = await pumpApp(
      tester,
      paired: true,
      extra: [
        party.crashAvailableProvider.overrideWithValue(true),
        party.crashReporterProvider.overrideWithValue(reports),
      ],
    );
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('settingsCrashReports')));
    expect(_switch(tester, 'settingsCrashReports').value, isFalse, reason: 'off until the adult answers');

    await tester.tap(find.byKey(const Key('settingsCrashReports')));
    await settle(tester);
    expect(_switch(tester, 'settingsCrashReports').value, isTrue);
    expect(app.prefs.getBool('crashConsent'), isTrue);
    expect(reports.enableCount, 1);
    expect(reports.enabled, isTrue);

    await tester.tap(find.byKey(const Key('settingsCrashReports')));
    await settle(tester);
    expect(app.prefs.getBool('crashConsent'), isFalse);
    expect(reports.disableCount, 1);
    expect(reports.enabled, isFalse);
  });
}

/// The switch behind [key] in the Settings.
SwitchListTile _switch(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key)));

/// The crash reporter the crash switch turns on and off, recording what it was
/// asked to do: `party_host/testing.dart` keeps the host's fakes, and this one
/// is the phone app's own (coding guidelines §2).
class _Reports implements party.CrashReporter {
  /// How many times the app turned reports on.
  int enableCount = 0;

  /// How many times the app turned reports off.
  int disableCount = 0;

  bool _on = false;

  @override
  bool get enabled => _on;

  @override
  Future<void> enable() async {
    enableCount++;
    _on = true;
  }

  @override
  Future<void> disable() async {
    disableCount++;
    _on = false;
  }

  @override
  void capture(Object error, StackTrace? stack, {String? where}) {}
}
