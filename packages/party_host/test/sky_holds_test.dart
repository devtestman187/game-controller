import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The drift of the sky behind the top page, as its painter last read it.
ValueListenable<Offset> _sky(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(ToyBackground), matching: find.byType(CustomPaint)).first,
  );
  return (paint.painter! as ToyBackgroundPainter).shift;
}

/// The drift of the round's own sky: the background the screen's
/// [ToyStillSky] stands on.
ValueListenable<Offset> _roundSky(WidgetTester tester) {
  final background = find.ancestor(of: find.byType(ToyStillSky), matching: find.byType(ToyBackground)).first;
  final paint = tester.widget<CustomPaint>(find.descendant(of: background, matching: find.byType(CustomPaint)).first);
  return (paint.painter! as ToyBackgroundPainter).shift;
}

/// Taps [target] and lets a pushed page's slide finish, without settling (a
/// drifting menu never settles).
Future<void> _pushed(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  // The puzzle library fills in a frame or two after its page is pushed.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a menu\'s sky drifts, and the Shape Race round\'s stands still', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome(), stillSky: false);

    final home = _sky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester).value, home + const Offset(6, 6), reason: 'the home screen is a menu');

    await _pushed(tester, find.byKey(const Key('openPlay')));
    final games = _sky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester).value, games + const Offset(6, 6), reason: 'the game picker is a menu');

    await _pushed(tester, find.byKey(const Key('pickShapeRace')));
    await _pushed(tester, find.byKey(const Key('puzzle-house')));
    final join = _sky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester).value, join + const Offset(6, 6), reason: 'the join screen is a menu');

    // A player that has just appeared counts as holding what it holds now:
    // settle P1's pad before its presses.
    await neutral(tester, fake, ['p1']);
    await startRound(tester, fake);
    expect(find.byType(ToyStillSky), findsOneWidget);
    final round = _roundSky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_roundSky(tester).value, round, reason: 'the round holds its sky still');
  });

  testWidgets('the Arena screen holds its sky still', (tester) async {
    await pumpHost(tester, screen: const StubHome(), stillSky: false);
    await _pushed(tester, find.byKey(const Key('openPlay')));
    await _pushed(tester, find.byKey(const Key('pickArena')));

    final arena = _roundSky(tester).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_roundSky(tester).value, arena);
  });
}
