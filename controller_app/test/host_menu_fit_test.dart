import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// How far [screen]'s list can scroll, in px: zero when everything fits without
/// scrolling.
double scrollRangeOf(WidgetTester tester, Type screen) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first)
    .position
    .maxScrollExtent;

/// One side of the join screen, which scrolls its own content when the screen
/// is too short for it.
double sideRangeOf(WidgetTester tester, String side) => tester
    .state<ScrollableState>(find.descendant(of: find.byKey(Key('side-$side')), matching: find.byType(Scrollable)))
    .position
    .maxScrollExtent;

void main() {
  // The screens are measured with a real font, as a device draws them (see
  // test_font.dart), and the puzzles are read once before the tests run (s9g).
  setUpAll(loadHostFonts);
  setUpAll(loadPuzzles);

  testWidgets('the phone\'s picker fits at 852x393 without scrolling, and its level list scrolls', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await settle(tester);

    // The picker: no title bar under the phone's bar, and 12 at the top of its
    // list, so its two cards, the settings button and its note fit.
    expect(scrollRangeOf(tester, party.GamesScreen), 0, reason: 'the picker fits');

    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);
    // A level is a card of the look's buttons now (M13 3b), so the four of them
    // scroll on a landscape phone; what they must not do is overflow.
    expect(scrollRangeOf(tester, party.ShapeRaceScreen), greaterThan(0), reason: 'the level list scrolls');
    expect(tester.takeException(), isNull);

    await tester.runAsync(host.dispose);
  });

  testWidgets('both sides of the join screen fit at 852x393 without scrolling', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await settle(tester);

    // Both sides fit: the right one empty, the left one with the own player and
    // "Room for 1 more" (the join screen's tighter gaps under the phone's bar).
    expect(sideRangeOf(tester, 'left'), 0, reason: 'the left side fits');
    expect(sideRangeOf(tester, 'right'), 0, reason: 'the right side fits');

    await tester.runAsync(host.dispose);
  });
}
