import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

/// The smallest screen the app runs at, the landscape phone the chip is read at and the largest one checked.
const _screens = {'568x320': Size(568, 320), '667x375': Size(667, 375), '956x440': Size(956, 440)};

/// The bar button's size in dp: the touch target it must keep at every screen.
const _minWidthDp = 96.0;
const _minHeightDp = 44.0;

/// A phone that shows a game behind its controls, as the host route does, so the compact bar is up.
class _ShownGame extends GameShownNotifier {
  @override
  bool build() => true;
}

final _barStart = find.byKey(const Key('barStart'));
final _padStart = find.byWidgetPredicate(
  (w) => w is SmallButton && w.button == ControllerButton.start && w.key != const Key('barStart'),
);

Future<TestApp> _pump(WidgetTester tester, {bool game = true, bool tv = false, Size? screen}) async {
  final app = await pumpApp(
    tester,
    paired: true,
    screen: screen ?? const Size(568, 320),
    extra: [
      if (tv) party.toyTvProvider.overrideWithValue(true),
      if (game) gameShownProvider.overrideWith(() => _ShownGame()),
    ],
  );
  app.client.emit(connected);
  await settle(tester);
  return app;
}

void main() {
  group('Start is on the pad outside a game and in the bar over a game', () {
    testWidgets('a game shown: the bar has a button labelled Pause and the pad has no Start', (tester) async {
      final app = await _pump(tester);
      app.client.setLayout(GameLayoutMessage(labels: {ControllerButton.start: 'Pause'}));
      await settle(tester);
      expect(_barStart, findsOneWidget);
      expect(find.descendant(of: _barStart, matching: find.text('Pause')), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Pause'), findsOneWidget, reason: 'the pad draws no second pill');
    });

    for (final mode in ['dpad', 'gyro', 'sticks']) {
      testWidgets('a game shown in $mode mode: the pad draws no Start pill', (tester) async {
        final app = await pumpApp(
          tester,
          paired: true,
          saved: {'padMode': mode},
          extra: [gameShownProvider.overrideWith(() => _ShownGame())],
        );
        app.client.emit(connected);
        await settle(tester);
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
        expect(_barStart, findsOneWidget);
        expect(_padStart, findsNothing);
      });
    }

    testWidgets('a layout that hides Start: the bar has no button', (tester) async {
      final app = await _pump(tester);
      app.client.setLayout(GameLayoutMessage(hidden: {ControllerButton.start}));
      await settle(tester);
      expect(_barStart, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the menu layout: no Start in the bar', (tester) async {
      final app = await _pump(tester);
      app.client.setLayout(party.menuLayout);
      await settle(tester);
      expect(_barStart, findsNothing);
    });

    testWidgets('no game shown: the pad keeps its Start pill and the bar has no button', (tester) async {
      await _pump(tester, game: false);
      expect(_barStart, findsNothing);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('a press on the bar button sends Start', (tester) async {
      final app = await _pump(tester);
      await tester.tap(_barStart);
      await tester.pump();
      expect(app.client.inputs, ['START 0,0', '0,0']);
    });

    for (final screen in _screens.entries) {
      for (final tv in [false, true]) {
        final where = '${screen.key} in the ${tv ? 'TV' : 'menu'} look';
        testWidgets('the bar button keeps a 96x44 target and nothing overflows at $where', (tester) async {
          await _pump(tester, tv: tv, screen: screen.value);
          final rect = tester.getRect(_barStart);
          expect(rect.height, greaterThanOrEqualTo(_minHeightDp), reason: 'height at $where');
          expect(rect.width, greaterThanOrEqualTo(_minWidthDp), reason: 'width at $where');
          expect(tester.takeException(), isNull, reason: 'a layout error at $where');
        });
      }
    }
  });
}
