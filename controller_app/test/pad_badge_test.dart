import 'package:controller/src/ui/bar_connection.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyBadge, ToyCharacter, toyAccessoryHeadroom;

import 'support/pump_app.dart';

void main() {
  group('the bar\'s badge (M13 step 8, rule 7)', () {
    testWidgets('it is the look\'s badge wearing P3\'s character, in the bar\'s own height', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 3));
      await settle(tester);
      final badge = tester.widget<ToyBadge>(find.byType(ToyBadge));
      expect(badge.number, 3);
      expect(badge.character, ToyCharacter.forPlayer(3), reason: 'it wears P3\'s accessory');
      expect(badge.diameter, playerBadgeDiameter);
      final box = tester.getSize(find.byKey(const Key('playerBadge')));
      expect(box.height, closeTo(playerBadgeDiameter + toyAccessoryHeadroom(playerBadgeDiameter), 0.01));
      expect(box.height, lessThanOrEqualTo(barRowHeightPx), reason: 'the disc and its headroom fit the chip');
      // The row the bar draws is the height it always was.
      expect(tester.getSize(find.byKey(const Key('connectionChip'))).height, barRowHeightPx);
      expect(topBarHeightPx, barTopPaddingPx + barRowHeightPx);
    });

    testWidgets('its tooltip still says whose it is', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2));
      await settle(tester);
      expect(find.byTooltip(PhoneText.youArePlayer(2)), findsOneWidget);
      expect(tester.widget<ToyBadge>(find.byType(ToyBadge)).character, ToyCharacter.forPlayer(2));
    });

    testWidgets('no player, no badge', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await settle(tester);
      expect(find.byKey(const Key('playerBadge')), findsNothing);
      expect(find.byType(ToyBadge), findsNothing);
    });
  });
}
