import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

void main() {
  Future<FakeHostService> openPanel(WidgetTester tester) async {
    final fake = await pumpApp(tester);
    await tapVisible(tester, find.text('Haptic test'));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('each button sends its event to the connected controllers and plays its sound', (tester) async {
    final fake = await openPanel(tester);
    expect(find.text('Sends to P1 iPhone 3F1C'), findsOneWidget);
    for (final e in HapticEvent.values) {
      await tester.tap(find.byKey(Key('fire-${e.name}')));
      await tester.pump();
    }
    expect(fake.haptics.map((h) => h.$1), [for (final e in HapticEvent.values) HapticEventMessage(event: e)]);
    expect(fake.haptics.every((h) => h.$2 == 'p1'), isTrue, reason: 'to every connected controller');
    expect(sounds.played, [for (final e in HapticEvent.values) e.name]);
    await tester.scrollUntilVisible(find.byKey(const Key('lastSent')), 200);
    expect(find.text('Last: tick, 100%, 30 ms (panel) → 1 controller'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intensity and duration steppers change what is sent', (tester) async {
    final fake = await openPanel(tester);
    // Nine events: the steppers are further down, as on the TV, so each press
    // scrolls its button into view first.
    Future<void> tapStepper(String tooltip) async {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }

    await tapStepper('Less Intensity');
    await tapStepper('Less Intensity');
    await tapStepper('More Duration');
    await tapStepper('More Duration');
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('200 ms'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('fire-error')));
    await tester.pump();
    expect(fake.haptics.single.$1, HapticEventMessage(event: HapticEvent.error, intensity: 0.8, durationMs: 200));

    // The limits hold, and the buttons stay usable there.
    for (var i = 0; i < 12; i++) {
      await tapStepper('More Intensity');
      await tapStepper('Less Duration');
    }
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Natural'), findsOneWidget);
  });

  testWidgets('works with the remote: Hit has focus and OK fires it', (tester) async {
    final fake = await openPanel(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(fake.haptics.single.$1.event, HapticEvent.hit);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(fake.haptics.last.$1.event, HapticEvent.success);
  });

  testWidgets('without a controller the sounds still play', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: const []),
    );
    fake.emit();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Haptic test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No controller connected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fire-hit')));
    await tester.pump();
    expect(sounds.played, ['hit']);
    await tester.scrollUntilVisible(find.byKey(const Key('lastSent')), 200);
    expect(find.textContaining('→ no controller'), findsOneWidget);
  });
}
