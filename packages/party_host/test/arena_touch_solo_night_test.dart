import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// A night's only player on a phone host that plays here (M14 bugs B-020, run
/// review finding 1): the round waits for this phone's own player, who readies
/// with the waiting card's Ready button as a pad's A would, and never starts
/// on its own.
void main() {
  /// What a phone host that plays here supplies: this phone's own player is in
  /// the round, and the host is worked by touch (m12-host-touch rules A and B).
  List<Override> ownPhoneOverrides(String id) => [
    ownPlayerIdProvider.overrideWithValue(id),
    hostTouchFirstProvider.overrideWithValue(true),
  ];

  testWidgets('a lone night player on a phone host starts the round with Ready, and not before', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      size: const Size(852, 393),
      overrides: ownPhoneOverrides('p1'),
    );
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'a night opens on its card');
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'the only player has not tapped Ready');
    expect(find.byKey(const Key('arena')), findsNothing, reason: 'no round runs before the tap');

    // A second of frames: the round starts on the player's Ready, never on its own.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('arena')), findsNothing, reason: 'nobody has tapped Ready');

    await tester.tap(find.byKey(const Key('arenaReady')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const Key('arenaWaitingCard')),
      findsNothing,
      reason: 'the only player is ready: the round starts',
    );
    expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the Ready tap is that player\'s A');
  });
}
