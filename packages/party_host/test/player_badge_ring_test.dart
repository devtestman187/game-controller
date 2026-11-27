import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/ui/player_badge_ring.dart';

import 'support/all_looks.dart';

const _ringKey = Key('playerBadgeRing');

/// Float slack for 37 / 0.88 * 0.88, which can land a hair under 37.
const _slack = 1e-9;

Future<void> _pump(WidgetTester tester, HostLook look, int number, {double size = 32}) => pumpHostLook(
  tester,
  look,
  framed: true,
  screen: Scaffold(
    body: Center(
      child: PlayerBadge(number: number, size: size),
    ),
  ),
);

void main() {
  testWidgets('players 1-6 draw no ring and players 7 and 8 do, in both looks', (tester) async {
    await forEachLook(tester, (look) async {
      for (var number = 1; number <= 8; number++) {
        await _pump(tester, look, number);
        expect(find.byKey(_ringKey), number > 6 ? findsOneWidget : findsNothing, reason: '$look player $number');
      }
    });
  });

  testWidgets('outside the host frame, as the phone app shows it, player 7 is a plain badge with no ring', (
    tester,
  ) async {
    await forEachLook(tester, (look) async {
      await pumpHostLook(
        tester,
        look,
        screen: const Scaffold(body: Center(child: PlayerBadge(number: 7))),
      );
      expect(find.byType(PlayerBadgeRing), findsNothing, reason: '$look');
      expect(find.byType(ToyBadge), findsOneWidget, reason: '$look');
      expect(tester.widget<ToyBadge>(find.byType(ToyBadge)).diameter, 32, reason: '$look: the default size');
    });
  });

  test('badgeNeedsRing is true only past the sixth colour slot', () {
    expect([for (var n = 1; n <= 8; n++) badgeNeedsRing(n)], [false, false, false, false, false, false, true, true]);
  });

  testWidgets('a ringed badge keeps its number and character and a disc over the number floor', (tester) async {
    await forEachLook(tester, (look) async {
      await _pump(tester, look, 7);
      final badge = tester.widget<ToyBadge>(find.byType(ToyBadge));
      expect(badge.number, 7, reason: '$look');
      expect(badge.character, ToyCharacter.forPlayer(7), reason: '$look');
      expect(badge.diameter, greaterThanOrEqualTo(badgeNumberMinDiameterPx - _slack), reason: '$look');
    });
  });

  testWidgets('the number of player 8 is at least 20 px in the frame and the ring box is square', (tester) async {
    await forEachLook(tester, (look) async {
      for (final number in [7, 8]) {
        await _pump(tester, look, number, size: 20);
        final badge = tester.widget<ToyBadge>(find.byType(ToyBadge));
        expect(badge.diameter * 0.55, greaterThanOrEqualTo(badgeNumberFloorPx - _slack), reason: '$look $number');
        final box = tester.getSize(find.byKey(_ringKey));
        expect(box.width, box.height, reason: '$look $number: the ring box is square');
        expect(box.width, greaterThan(badge.diameter), reason: '$look $number: the ring sits outside the disc');
      }
    });
  });
}
