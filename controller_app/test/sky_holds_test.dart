import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyBackground, ToyBackgroundPainter;

import 'support/pump_app.dart';

/// The drift of the sky behind the top page, as its painter last read it.
ValueListenable<Offset> _sky(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(ToyBackground), matching: find.byType(CustomPaint)).first,
  );
  return (paint.painter! as ToyBackgroundPainter).shift;
}

void main() {
  testWidgets('the Connect screen\'s sky drifts', (tester) async {
    await pumpApp(tester, stillSky: false);
    final connect = _sky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester).value, connect + const Offset(6, 6), reason: 'Connect is a menu');
  });

  testWidgets('the pad holds its sky still', (tester) async {
    await pumpApp(tester, paired: true, stillSky: false);
    final pad = _sky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester).value, pad, reason: 'the pad holds its sky still');
  });
}
