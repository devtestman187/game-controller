import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  group('store builds (M8)', () {
    testWidgets('"Try without a TV" shows the controls working with no host', (tester) async {
      final app = await pumpApp(tester);
      expect(find.text('Connect to a TV'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tryWithoutTv')));
      await settle(tester);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.textContaining('Demo, no TV'), findsOneWidget);
      expect(find.text('Demo: a TV would get nothing pressed'), findsOneWidget);

      final a = await tester.startGesture(at(tester, const Key('faceButtons'), const Offset(0.5, 0.81)));
      await tester.pump();
      expect(find.textContaining('Demo: a TV would get A'), findsOneWidget);
      expect(app.haptics.ticks, isNotEmpty, reason: 'the phone still ticks');
      await a.up();
      await tester.pump();

      // Stick mode shows it too.
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('demoReadout')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // A TV connecting ends the demo.
      app.client.emit(connected);
      await tester.pump();
      expect(find.byKey(const Key('demoReadout')), findsNothing);
    });

    testWidgets('Settings shows the version and links to the privacy policy and tester guide', (tester) async {
      await pumpApp(tester, paired: true);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('privacyPolicy')));
      expect(find.text('Thumb Party 0.14.0 (dev)'), findsOneWidget);
      expect(find.textContaining('privacy.html'), findsOneWidget);
      expect(find.byKey(const Key('testerGuide')), findsOneWidget);
    });
  });
}
