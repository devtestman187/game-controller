import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/joined.dart';
import 'support/pump_app.dart';

/// The drift of the sky the page holding [page] stands on, as its painter last
/// read it: every page carries its own [party.ToyBackground] (design section
/// 5), and the nearest one above the page is its own.
ValueListenable<Offset> _sky(WidgetTester tester, Finder page) {
  final background = find.ancestor(of: page, matching: find.byType(party.ToyBackground)).first;
  final paints = tester.widgetList<CustomPaint>(find.descendant(of: background, matching: find.byType(CustomPaint)));
  return (paints.first.painter! as party.ToyBackgroundPainter).shift;
}

/// Expects [after] to be [before] plus a second of drift, which a sky that
/// drifts covers in one second (design section 6).
void _expectDrifted(Offset before, Offset after) {
  expect(after.dx, moreOrLessEquals(before.dx + 6, epsilon: 0.01));
  expect(after.dy, moreOrLessEquals(before.dy + 6, epsilon: 0.01));
}

void main() {
  testWidgets('the Connect screen\'s sky drifts', (tester) async {
    await pumpApp(tester, stillSky: false);
    final connect = _sky(tester, find.byType(ConnectScreen)).value;
    await tester.pump(const Duration(seconds: 1));
    _expectDrifted(connect, _sky(tester, find.byType(ConnectScreen)).value);
  });

  testWidgets('the pad holds its sky still', (tester) async {
    await pumpApp(tester, paired: true, stillSky: false);
    final pad = _sky(tester, find.byType(ControllerScreen)).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester, find.byType(ControllerScreen)).value, pad, reason: 'the pad holds its sky still');
  });

  testWidgets('the joined view holds its sky still', (tester) async {
    final app = await pumpApp(tester, paired: true, stillSky: false);
    app.client.emit(connected);
    await settle(tester);
    app.client.nowMs = 1000;
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(arenaFrame(0));
    await settle(tester);
    // The game is up, in a still sky of its own (design section 6, M13 9
    // review).
    expect(find.ancestor(of: find.byType(JoinedView), matching: find.byType(party.ToyStillSky)), findsOneWidget);
    final game = _sky(tester, find.byType(JoinedView)).value;
    await tester.pump(const Duration(seconds: 1));
    expect(_sky(tester, find.byType(JoinedView)).value, game, reason: 'the joined view holds its sky still');
  });

  testWidgets('a hosting phone\'s picker drifts', (tester) async {
    await pumpHostApp(tester, stillSky: false);
    await enterHostMode(tester);
    // The picker is a menu, and no pad stands under it while no round is on
    // (M13 9 review): its sky drifts as the TV's do.
    final picker = _sky(tester, find.byType(party.GamesScreen)).value;
    await tester.pump(const Duration(seconds: 1));
    _expectDrifted(picker, _sky(tester, find.byType(party.GamesScreen)).value);
    await tester.runAsync(hostOf(tester).dispose);
  });
}
