import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

/// Opens a round with the phones [numbers] joined (phone 2 is `p2`), started by
/// the phone [starter] with Start, and returns the fake host.
Future<FakeHostService> _startRound(WidgetTester tester, List<int> numbers, int starter) async {
  final fake = await pumpHost(tester, screen: const StubHome());
  var state = fake.state;
  for (final n in numbers) {
    state = withController(state, phoneInfo('p$n', n));
  }
  fake.state = state;
  fake.emit();
  await neutral(tester, fake, [for (final n in numbers) 'p$n']);
  await openJoin(tester);
  for (final n in numbers) {
    await press(tester, fake, 'p$n', GamepadButton.a);
  }
  await press(tester, fake, 'p$starter', GamepadButton.start);
  await navigated(tester);
  return fake;
}

void main() {
  testWidgets(
    'during a pause the phones of the players who may resume get Resume; another phone keeps its menu label',
    (tester) async {
      // P1 and P2 are here, and P3 is the other phone: P2 pauses, so P2 and P1 may resume.
      final fake = await _startRound(tester, [1, 2, 3], 1);
      final host = fake.gameHost;
      await press(tester, fake, 'p2', GamepadButton.start);
      await navigated(tester);
      expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

      for (final id in ['p1', 'p2']) {
        expect(host.layouts[id]!.labels[ControllerButton.b], 'Resume', reason: '$id may resume');
        expect(host.layouts[id]!.labels[ControllerButton.start], 'Resume', reason: '$id may resume');
      }
      expect(host.layouts['p3']!.labels[ControllerButton.b], 'Back', reason: 'P3 keeps the menu label');
      expect(host.layouts['p3']!.labels[ControllerButton.a], 'OK');
      expect(host.layouts['p3']!.labels[ControllerButton.start], isNull, reason: 'P3 gets no Start label');
    },
  );

  testWidgets('during a pause a phone that may not resume is still filtered out: its Start and B do nothing', (
    tester,
  ) async {
    final fake = await _startRound(tester, [1, 2, 3], 1);
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    await press(tester, fake, 'p3', GamepadButton.start);
    await navigated(tester);
    await press(tester, fake, 'p3', GamepadButton.b);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget, reason: 'P3 may not resume or close the menu');
  });

  testWidgets('with nobody who may resume here every phone gets Resume', (tester) async {
    // P2 pauses, then P1 and P2 both go away: no one who may resume is here, and P3 is still on its phone.
    final fake = await _startRound(tester, [1, 2, 3], 1);
    final host = fake.gameHost;
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    host.setAway('p1', isAway: true);
    host.setAway('p2', isAway: true);
    await tester.pump();
    await navigated(tester);
    expect(host.layouts['p3']!.labels[ControllerButton.start], 'Resume');
    expect(host.layouts['p3']!.labels[ControllerButton.b], 'Resume');
  });
}
