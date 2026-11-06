import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/ui/latency_screen.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('the latency screen shows ping and input delay against the target', (tester) async {
    final fake = await pumpApp(tester);
    await tapVisible(tester, find.text('Latency'));
    await tester.pumpAndSettle();
    expect(find.byType(LatencyScreen), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget);
    expect(find.text('Within the 50 ms target'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inputDelay-p1'))).data, '9 ms');
    expect(find.text('p95 18 · max 41 ms · ± 4 ms'), findsOneWidget);
    expect(find.text('10 ms'), findsOneWidget, reason: 'session average');
    expect(find.text('min 8 · p95 60 · max 140 ms'), findsOneWidget);
    // Save log is focused: OK saves and says where.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(fake.exports, 1);
    expect(find.textContaining('Log saved to D:/logs/controller-test-log.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the latency screen fits a small window', (tester) async {
    await pumpApp(tester, size: const Size(600, 800));
    await tapVisible(tester, find.text('Latency'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the latency screen breaks the delay into stages', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text('Latency'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('stageSent-p1'))).data, '9 ms');
    expect(tester.widget<Text>(find.byKey(const Key('stageDrawn-p1'))).data, '–');
  });
}
