import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/ui/shader_spike_rows.dart';
import 'package:tvtest/src/ui/shader_spike_screen.dart';

import 'support/pump_app.dart';

/// Opens the Look test screen from the home and lets its shader load answer.
Future<void> openSpike(WidgetTester tester) async {
  await pumpApp(tester);
  await tapVisible(tester, find.text('Look test'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The painter of the row whose key is [key], as it last built.
ShaderSpikePainter painterOf(WidgetTester tester, String key) {
  final paint = tester.widget<CustomPaint>(find.byKey(Key(key)));
  final painter = paint.painter;
  expect(painter, isA<ShaderSpikePainter>());
  return painter as ShaderSpikePainter;
}

void main() {
  testWidgets('the Look test button opens the spike, which says what the shader did', (tester) async {
    await openSpike(tester);
    expect(find.byType(ShaderSpikeScreen), findsOneWidget);
    // Whatever this device can do, the line says it: on with a load time, or
    // off with the reason. Under `flutter test` the shader asset isn't there,
    // so this reads "Shader: off: ..." (see the spike's report).
    final status = tester.widget<Text>(find.byKey(const Key('shaderStatus'))).data;
    expect(status, isNotNull);
    expect(status!.startsWith('Shader: on (loaded in ') || status.startsWith('Shader: off: '), isTrue, reason: status);
    expect(find.byKey(const Key('frameStats')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both rows are labelled and turn one whole turn in 8 s', (tester) async {
    await openSpike(tester);
    expect(find.text('With the shader'), findsOneWidget);
    expect(find.text('Without it (the fallback)'), findsOneWidget);
    final before = painterOf(tester, 'lookRowShader').turn;
    await tester.pump(const Duration(seconds: 2));
    final after = painterOf(tester, 'lookRowShader').turn;
    expect((after - before) % 1.0, closeTo(0.25, 0.05), reason: 'a quarter of one turn in 2 s of 8 s');
    expect(painterOf(tester, 'lookRowFallback').turn, after, reason: 'both rows turn together');
  });

  testWidgets('Stress adds 60 shapes to each row and says so', (tester) async {
    await openSpike(tester);
    expect(find.text('Stress: off'), findsOneWidget);
    expect(painterOf(tester, 'lookRowShader').stress, isFalse);
    await tester.tap(find.byKey(const Key('stressToggle')));
    await tester.pump();
    expect(find.text('Stress: on'), findsOneWidget);
    expect(painterOf(tester, 'lookRowShader').stress, isTrue);
    expect(painterOf(tester, 'lookRowFallback').stress, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back leaves the spike screen', (tester) async {
    await openSpike(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShaderSpikeScreen), findsNothing);
  });
}
