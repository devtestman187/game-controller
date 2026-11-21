import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('a PlayerBadge wears its player\'s character, so the TV\'s panels show which worker is whose', (
    tester,
  ) async {
    await pumpHost(
      tester,
      screen: const Scaffold(body: Center(child: PlayerBadge(number: 4))),
    );

    final badge = tester.widget<ToyBadge>(find.byType(ToyBadge));
    expect(badge.number, 4, reason: 'the number stays: a menu still counts the players off');
    expect(badge.character, ToyCharacter.forPlayer(4), reason: 'player 4 is the cap in teal');
  });

  testWidgets('outside the frame a pad keeps the badge size it asks for', (tester) async {
    // A controller's bar draws its badge outside the host frame, in fixed dp
    // (controller_app's playerBadgeDiameter): the floor is the frame's, so a
    // pad's 28 px badge stays 28 px.
    await pumpHost(
      tester,
      screen: const Scaffold(body: Center(child: PlayerBadge(number: 4, size: 28))),
    );

    expect(tester.widget<ToyBadge>(find.byType(ToyBadge)).diameter, 28);
  });
}
