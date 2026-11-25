import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// The phone sizes the manual address row must hold at: the narrowest phones
/// (320 wide), a common 375 one, and two landscape ones (a 320 tall phone is
/// the shortest the app runs in).
const narrowScreens = {
  '320x640': Size(320, 640),
  '375x667': Size(375, 667),
  '568x320': Size(568, 320),
  '640x360': Size(640, 360),
};

/// The text scale a user who asks for bigger text gets (the system setting), on
/// the narrowest phone.
const largeTextScale = 1.3;

void main() {
  group('the manual address row fits a narrow screen (item 9a)', () {
    for (final entry in narrowScreens.entries) {
      testWidgets('the address field and Connect sit inside ${entry.key} in the menu look', (tester) async {
        await expectManualRowFits(tester, screen: entry.value, tv: false);
      });

      testWidgets('the address field and Connect sit inside ${entry.key} in the TV look', (tester) async {
        await expectManualRowFits(tester, screen: entry.value, tv: true);
      });
    }

    testWidgets('the address field and Connect sit inside 320x640 at text scale 1.3 in the menu look', (tester) async {
      await expectManualRowFits(tester, screen: const Size(320, 640), tv: false, textScale: largeTextScale);
    });

    testWidgets('the address field and Connect sit inside 320x640 at text scale 1.3 in the TV look', (tester) async {
      await expectManualRowFits(tester, screen: const Size(320, 640), tv: true, textScale: largeTextScale);
    });
  });
}

/// Pumps the Connect screen at [screen] in one look, with the system's text
/// scale at [textScale], and checks that nothing overflows and that the address
/// field and the Connect button lie wholly inside the screen.
Future<void> expectManualRowFits(
  WidgetTester tester, {
  required Size screen,
  required bool tv,
  double textScale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => overflows.add(details.exceptionAsString());
  addTearDown(() => FlutterError.onError = previous);
  await pumpApp(tester, screen: screen, extra: [if (tv) party.toyTvProvider.overrideWithValue(true)]);
  await reachConnect(tester);

  final label = '${screen.width.toInt()}x${screen.height.toInt()} at scale $textScale';
  expect(overflows, isEmpty, reason: 'the Connect screen overflows at $label');
  final bounds = Offset.zero & screen;
  expectInside(tester, find.byKey(const Key('manualAddress')), bounds, 'the address field at $label');
  expectInside(tester, find.text('Connect'), bounds, 'the Connect button at $label');
}

/// Checks that [finder]'s box lies wholly inside [bounds], naming [what] when it does not.
void expectInside(WidgetTester tester, Finder finder, Rect bounds, String what) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(bounds.left), reason: '$what starts left of the screen');
  expect(rect.top, greaterThanOrEqualTo(bounds.top), reason: '$what starts above the screen');
  expect(rect.right, lessThanOrEqualTo(bounds.right), reason: '$what runs past the right edge');
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom), reason: '$what runs past the bottom edge');
}
