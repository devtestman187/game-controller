import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyBackground;
import 'package:tvtest/src/tv_text.dart';
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
  testWidgets('the Look test button opens the spike, which says what each shader did', (tester) async {
    await openSpike(tester);
    expect(find.byType(ShaderSpikeScreen), findsOneWidget);
    // Whatever this device can do, each line says it: on with its load and
    // warm-up time, or off with the reason. Under `flutter test` the shader
    // assets aren't there, so these read "Shade: off: ..." and "Backdrop:
    // off: ..." (see the spike's report).
    final shade = tester.widget<Text>(find.byKey(const Key('shadeStatus'))).data;
    final backdrop = tester.widget<Text>(find.byKey(const Key('backdropStatus'))).data;
    expect(shade, isNotNull);
    expect(backdrop, isNotNull);
    expect(shade!.startsWith('Shade: on (') || shade.startsWith('Shade: off: '), isTrue, reason: shade);
    expect(backdrop!.startsWith('Backdrop: on (') || backdrop.startsWith('Backdrop: off: '), isTrue, reason: backdrop);
    expect(find.byKey(const Key('frameStats')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Claude's step 6 review: each palette with the shader and then without it,
  // side by side, so a device shows whether the two fills draw the same sky.
  testWidgets('the sky row shows Sunny and Night, each with the shader and with the fallback', (tester) async {
    await openSpike(tester);
    final shapes = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text(TvText.sky), 200, scrollable: shapes);
    for (final palette in [TvText.skySunny, TvText.skyNight]) {
      expect(find.text(palette), findsOneWidget);
      expect(find.text('$palette, ${TvText.skyFallback}'), findsOneWidget);
    }
    // The four boxes' skies, and the screen's own.
    expect(find.byType(ToyBackground), findsAtLeastNWidgets(5));
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
