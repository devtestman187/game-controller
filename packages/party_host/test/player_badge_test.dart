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
}
