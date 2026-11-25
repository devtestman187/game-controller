import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// The Settings' Show tips switch: on until the player turns it off, and the
/// choice is saved as `showTips` for Home to read the next time it is idle.
void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';

    testWidgets('with no saved key the Show tips switch is on, in $look', (tester) async {
      await pumpApp(tester, paired: true, extra: [if (tv) party.toyTvProvider.overrideWithValue(true)]);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('showTipsSwitch')));
      expect(_switch(tester).value, isTrue, reason: 'a missing key means show');
      expect(tester.getSize(find.byKey(const Key('showTipsSwitch'))).height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('turning Show tips off saves false, in $look', (tester) async {
      final app = await pumpApp(tester, paired: true, extra: [if (tv) party.toyTvProvider.overrideWithValue(true)]);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('showTipsSwitch')));
      await tapVisible(tester, find.byKey(const Key('showTipsSwitch')));
      await settle(tester);
      expect(_switch(tester).value, isFalse);
      expect(app.prefs.getBool('showTips'), isFalse, reason: 'the choice is saved for the next launch');
    });

    testWidgets('turning Show tips on saves true, in $look', (tester) async {
      final app = await pumpApp(
        tester,
        paired: true,
        saved: {'showTips': false},
        extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
      );
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('showTipsSwitch')));
      expect(_switch(tester).value, isFalse, reason: 'the saved off is read');
      await tapVisible(tester, find.byKey(const Key('showTipsSwitch')));
      await settle(tester);
      expect(_switch(tester).value, isTrue);
      expect(app.prefs.getBool('showTips'), isTrue);
    });
  }

  testWidgets('a fresh launch reads a saved off Show tips as off', (tester) async {
    await pumpApp(tester, paired: true, saved: {'showTips': false});
    await openSettings(tester);
    await scrollTo(tester, find.byKey(const Key('showTipsSwitch')));
    expect(_switch(tester).value, isFalse);
  });
}

/// The Show tips switch in the Settings.
SwitchListTile _switch(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(const Key('showTipsSwitch')));
