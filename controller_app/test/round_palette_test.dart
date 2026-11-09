import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The palette the app draws now, as the look above the controller screen has
/// it: off stage too, so a page pushed over it reads the same look.
party.ToyPalette paletteOf(WidgetTester tester) =>
    party.ToyLookScope.of(tester.element(find.byType(ControllerScreen, skipOffstage: false).first)).palette;

void main() {
  testWidgets('a joined game freezes the palette, and the next page after it turns Night', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    final app = await pumpApp(tester, paired: true, clock: () => now);
    app.client.emit(connected);
    await settle(tester);
    app.client.nowMs = 1000;
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(arenaFrame(0));
    await settle(tester);
    expect(paletteOf(tester), party.ToyPalette.sunny, reason: 'the game starts before 19:00');
    // The clock crosses into Night while the game is still on: the palette
    // stays what the game started in (D1).
    now = DateTime(2026, 11, 8, 19, 1);
    await openSettings(tester);
    expect(paletteOf(tester), party.ToyPalette.sunny, reason: 'a page over a game keeps the game\'s palette');
    await closeSettings(tester);
    expect(paletteOf(tester), party.ToyPalette.sunny, reason: 'so does going back to the pad');
    app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
    await settle(tester);
    await openSettings(tester);
    expect(
      paletteOf(tester),
      party.ToyPalette.night,
      reason: 'the first page after the game works the palette out again',
    );
  });
}
