import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:toy_look/toy_look.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('the join screen shows a phone\'s nickname and wears its character on the badge', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    const crown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);
    fake.state = withController(fake.state, phoneInfo('p3', 2, name: 'Mia', character: crown));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p3']);
    await openJoin(tester);
    await press(tester, fake, 'p3', GamepadButton.a);

    expect(find.text('P2 Mia'), findsOneWidget);
    final badge = tester.widget<ToyBadge>(find.byWidgetPredicate((w) => w is ToyBadge && w.number == 2));
    expect(badge.character, ToyCharacter.of(crown, 2));
    expect(badge.character!.colourSlot, 4);
    expect(badge.character!.accessory, ToyAccessory.crown);
  });

  testWidgets('a phone that chose nothing wears its number\'s default character on the badge', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await press(tester, fake, 'p1', GamepadButton.a);

    expect(find.text('P1 iPhone 3F1C'), findsOneWidget);
    final badge = tester.widget<ToyBadge>(find.byWidgetPredicate((w) => w is ToyBadge && w.number == 1));
    expect(badge.character, ToyCharacter.forPlayer(1));
  });
}
