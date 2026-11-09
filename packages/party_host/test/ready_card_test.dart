import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The "Get ready" card's count (M13 3b, mock-up `ready`): each number in the
/// look's clock type, three times its size, popping from 1.3 to 1.0 in 250 ms
/// as it changes while the look's effects are on, and still when they are off.
ToyLook _look({bool effects = true}) => ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: effects);

Widget _screen(ToyLook look, int seconds, {bool reduceMotion = false}) => ToyStillSky(
  child: ToyLookScope(
    look: look,
    child: MaterialApp(
      theme: toyTheme(look),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: ReadyCard(seconds: seconds)),
        ),
      ),
    ),
  ),
);

/// The scale the count is drawn at: its pop's outer transform.
double _scaleOf(WidgetTester tester) => tester
    .widget<Transform>(
      find.ancestor(of: find.byKey(const Key('getReadyCount')), matching: find.byType(Transform)).first,
    )
    .transform
    .entry(0, 0);

void main() {
  testWidgets('each count pops from 1.3 to 1.0 in 250 ms while the effects are on', (tester) async {
    await tester.pumpWidget(_screen(_look(), 3));
    expect(_scaleOf(tester), closeTo(readyPopFrom, 1e-9));
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    expect(_scaleOf(tester), closeTo(readyPopTo, 1e-9));

    // The next second pops again.
    await tester.pumpWidget(_screen(_look(), 2));
    expect(_scaleOf(tester), closeTo(readyPopFrom, 1e-9));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('with the effects off the count is still', (tester) async {
    await tester.pumpWidget(_screen(_look(effects: false), 3));
    expect(_scaleOf(tester), readyPopTo);
    await tester.pumpWidget(_screen(_look(effects: false), 2));
    expect(_scaleOf(tester), readyPopTo);
  });

  testWidgets('with reduced motion asked for the count is still', (tester) async {
    await tester.pumpWidget(_screen(_look(), 3, reduceMotion: true));
    expect(_scaleOf(tester), readyPopTo);
    await tester.pumpWidget(_screen(_look(), 2, reduceMotion: true));
    expect(_scaleOf(tester), readyPopTo);
  });

  testWidgets('the card fits a phone\'s screen and a TV\'s', (tester) async {
    for (final (size, tv) in [(const Size(852, 393), false), (const Size(960, 540), true)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(ToyLook.build(palette: ToyPalette.night, tv: tv, effects: true), 3));
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('the count is the clock\'s family at three times its size, in ink on the paper', (tester) async {
    final look = _look();
    await tester.pumpWidget(_screen(look, 3));
    final count = tester.widget<Text>(find.byKey(const Key('getReadyCount')));
    expect(count.style!.fontFamily, look.type.clock.fontFamily);
    expect(count.style!.fontSize, look.type.clock.fontSize! * readyCountShare);
    expect(count.style!.color, look.colors.ink);
    final card = tester.widget<ToyCard>(find.byKey(const Key('getReady')));
    expect(card.header, isNull, reason: 'the ready card has no header band');
  });
}
