import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The palette the app draws now, as the look above the controller screen has
/// it: off stage too, so a page pushed over it reads the same look.
party.ToyPalette paletteOf(WidgetTester tester) =>
    party.ToyLookScope.of(tester.element(find.byType(ControllerScreen, skipOffstage: false).first)).palette;

void main() {
  // A joined phone follows its own Look setting (design D8), as it always has,
  // and a change shows at once: the game in progress included (M14 bug t1).
  testWidgets('a joined game follows its own Look setting at once, and Auto\'s clock on the next page', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    final app = await pumpApp(tester, paired: true, clock: () => now);
    app.client.emit(connected);
    await settle(tester);
    app.client.nowMs = 1000;
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(arenaFrame(0));
    await settle(tester);
    expect(paletteOf(tester), party.ToyPalette.sunny, reason: 'the game starts before 19:00, on Auto');

    final container = ProviderScope.containerOf(tester.element(find.byType(ControllerScreen).first));
    container.read(party.lookSettingsProvider.notifier).setChoice(party.LookChoice.night);
    await settle(tester);
    expect(paletteOf(tester), party.ToyPalette.night, reason: 'this phone\'s setting shows at once, mid-game too');
    expect(find.byType(ControllerScreen), findsOneWidget, reason: 'the game plays on');

    // Auto reads the clock at the set moments: 18:59 is Sunny, and a page
    // opened over the game after 19:00 turns it Night there and then.
    container.read(party.lookSettingsProvider.notifier).setChoice(party.LookChoice.auto);
    await settle(tester);
    expect(paletteOf(tester), party.ToyPalette.sunny, reason: 'Auto at 18:59 is Sunny');
    now = DateTime(2026, 11, 8, 19, 1);
    await openSettings(tester);
    expect(paletteOf(tester), party.ToyPalette.night, reason: 'the page works the palette out again');
    await closeSettings(tester);
    expect(paletteOf(tester), party.ToyPalette.night, reason: 'so does going back to the pad');
  });
}
