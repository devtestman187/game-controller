import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// The Arena's waiting card: the own player's row is a label for a thumb (M14
/// bugs B-025, the owner's option A). A tap on it does nothing; the card's
/// Ready button readies that player and takes it back, and a joined phone's A,
/// the remote's OK and Enter on the focused row still do too (B-013).
void main() {
  /// What a phone host that plays here supplies: this phone's own player is in
  /// the round, and the host is worked by touch (m12-host-touch rules A and B).
  List<Override> ownPhoneOverrides(String id) => [
    ownPlayerIdProvider.overrideWithValue(id),
    hostTouchFirstProvider.overrideWithValue(true),
  ];

  /// Home → Play → the Arena's card on a phone in landscape, with the host's
  /// own player and [phones] more phones on the roster, every pad quiet so the
  /// card waits for the test.
  Future<FakeHostService> openTouchCard(WidgetTester tester, {List<String> phones = const []}) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: ownPhoneOverrides('p1'),
    );
    for (final id in phones) {
      fake.state = withController(fake.state, phoneInfo(id, 2));
    }
    if (phones.isNotEmpty) fake.emit();
    await neutral(tester, fake, ['p1', ...phones]);
    await openArenaCard(tester);
    return fake;
  }

  testWidgets(
    'a tap on the own player\'s row does not ready it, where a tap on another player\'s row readies that one',
    (tester) async {
      await openTouchCard(tester, phones: ['p2']);
      expect(find.byKey(const Key('notReady-p1')), findsOneWidget);

      final row = tester.getRect(find.byKey(const Key('arenaPlayer-p1')));
      expect(row.top, greaterThanOrEqualTo(0.0));
      expect(row.bottom, lessThanOrEqualTo(393.0), reason: 'the row is above the fold, so the tap lands on it');
      await tester.tapAt(row.center);
      await tester.pump();
      expect(
        find.byKey(const Key('notReady-p1')),
        findsOneWidget,
        reason: 'the own player\'s row is a label, not its A',
      );
      expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'the card stays where it was');

      // Another player's row keeps its tap: only the host device's own row is
      // the label.
      await tester.tap(find.byKey(const Key('arenaPlayer-p2')));
      await tester.pump();
      expect(
        find.byKey(const Key('ready-p2')),
        findsOneWidget,
        reason: 'a joined phone\'s row still readies it on a tap',
      );
      expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'and only that row changed');
    },
  );

  testWidgets('the card\'s Ready button readies the own player and takes it back', (tester) async {
    await openTouchCard(tester);
    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    expect(find.byKey(const Key('ready-p1')), findsOneWidget, reason: 'the button is that player\'s A');

    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'a second tap takes the ready back');
  });

  testWidgets('a joined phone\'s A on the focused own row still readies that player', (tester) async {
    final fake = await openTouchCard(tester, phones: ['p2']);
    expect(focused(tester, 'arenaPlayer-p1'), isFalse);

    await focusRow(tester, 'p1');
    expect(focused(tester, 'arenaPlayer-p1'), isTrue, reason: 'the own row still takes the focus');
    await press(tester, fake, 'p2', GamepadButton.a);
    expect(find.byKey(const Key('ready-p1')), findsOneWidget, reason: 'A presses the focused row, as on every menu');
  });

  testWidgets('the remote\'s OK and Enter on the focused own row still ready it, and take it back', (tester) async {
    await openTouchCard(tester);
    await focusRow(tester, 'p1');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.byKey(const Key('ready-p1')), findsOneWidget, reason: 'the remote\'s OK presses the focused row');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.byKey(const Key('notReady-p1')),
      findsOneWidget,
      reason: 'Enter presses it too, and takes the ready back',
    );
  });
}
