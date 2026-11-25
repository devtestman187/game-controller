import 'dart:io';
import 'dart:math' as math;

import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/bar_modes.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// The screens the compact game bar is measured at: the smallest the app runs at (568x320), the landscape phone the
/// chip is read at (667x375) and the largest one checked (956x440).
const _screens = {'568x320': Size(568, 320), '667x375': Size(667, 375), '956x440': Size(956, 440)};

/// A Start button's width in dp, and the gap between it and Select: the two sizes the owner asked whether the bar
/// leaves room for.
const _startButtonWidthDp = 96.0;
const _buttonGapDp = 8.0;
const _startAndSelectWidthDp = 2 * _startButtonWidthDp + _buttonGapDp;

/// A phone that shows a game behind its controls, as the host route does, so the compact bar is up.
class _ShownGame extends GameShownNotifier {
  @override
  bool build() => true;
}

/// The compact bar's measures in dp, read off the laid-out widgets: where the left group ends, where the right group
/// starts, and the height of the bar's row.
({double leftRight, double rightLeft, double rowHeight}) _measureBar(WidgetTester tester) {
  final connection = tester.getRect(find.byKey(const Key('connectionButton')));
  var leftRight = connection.right;
  final badge = find.byKey(const Key('playerBadge'));
  if (badge.evaluate().isNotEmpty) leftRight = math.max(leftRight, tester.getRect(badge).right);

  final mode = tester.getRect(find.byType(ModeMenuButton));
  final more = tester.getRect(find.byKey(const Key('moreMenu')));
  final rightLeft = math.min(mode.left, more.left);

  final bar = find.byWidgetPredicate((w) => w is Padding && w.padding == barPadding);
  final row = find.descendant(of: bar, matching: find.byType(Row)).first;
  return (leftRight: leftRight, rightLeft: rightLeft, rowHeight: tester.getRect(row).height);
}

String _dp(double value) => value.toStringAsFixed(1);

void main() {
  for (final screen in _screens.entries) {
    for (final tv in [false, true]) {
      for (final withPlayer in [false, true]) {
        final look = tv ? 'TV' : 'menu';
        final badge = withPlayer ? 'yes' : 'no';
        final where = '${screen.key} in the $look look, player badge $badge';
        testWidgets('the compact game bar is measured for Start and Select at $where', (tester) async {
          final app = await pumpApp(
            tester,
            paired: true,
            screen: screen.value,
            extra: [
              if (tv) party.toyTvProvider.overrideWithValue(true),
              gameShownProvider.overrideWith(() => _ShownGame()),
            ],
          );
          app.client.emit(withPlayer ? connected.copyWith(player: 1) : connected);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'a layout error was thrown at $where');
          expect(find.byKey(const Key('connectionButton')), findsOneWidget, reason: 'no compact bar at $where');

          final m = _measureBar(tester);
          final free = m.rightLeft - m.leftRight;
          final fitsStart = free >= _startButtonWidthDp;
          final fitsStartAndSelect = free >= _startAndSelectWidthDp;
          stdout.writeln(
            '$where: badge=$badge leftRight=${_dp(m.leftRight)} rightLeft=${_dp(m.rightLeft)} '
            'free=${_dp(free)} fits96=$fitsStart fits200=$fitsStartAndSelect rowHeight=${_dp(m.rowHeight)}',
          );
        });
      }
    }
  }
}
