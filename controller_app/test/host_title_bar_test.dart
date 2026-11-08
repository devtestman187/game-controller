import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/ui/bar_modes.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// The phone the bug was shot on, in landscape: an iPhone 15 (the tests' own
/// screen, unless one asks for another).
const phoneScreenHeightPx = 393.0;

/// The parts of the phone's own bar: the host's chip and code, the mode's
/// three labels, Settings and Diagnostics (m12-host-touch rule 1).
List<(String, Finder)> barParts() => [
  ('the host chip', find.byKey(const Key('hostChip'))),
  ('the mode labels', find.byType(BarModes)),
  ('Settings', find.byTooltip('Settings')),
  ('Diagnostics', find.byTooltip('Diagnostics')),
];

/// [screen]'s title bar, the one [party.HostScreen] draws.
Finder titleBarOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byKey(const Key('hostTitleBar')));

/// The fill and the ring the button under [key] draws this frame (m12 bug
/// 1107f rule A), read off the Material it paints.
({Color? fill, double ring}) drawn(WidgetTester tester, String key) {
  final material = tester.widget<Material>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Material)).first,
  );
  return (fill: material.color, ring: (material.shape! as OutlinedBorder).side.width);
}

/// Checks that [screen]'s title bar starts below the phone's bar and meets none
/// of its parts (m12 bug 1107f rule C): its title ran into the bar's mode
/// labels, and its back arrow hid under the player's chip.
void expectRoomBelowTheBar(WidgetTester tester, Type screen) {
  final bar = tester.getRect(titleBarOf(screen));
  expect(bar.top, topBarHeightPx, reason: 'the title bar starts below the phone bar');
  for (final (name, part) in barParts()) {
    if (part.evaluate().isEmpty) continue;
    expect(bar.overlaps(tester.getRect(part)), isFalse, reason: 'the title bar meets $name');
  }
}

void main() {
  // The puzzle files are read once, before any test runs (s9g).
  setUpAll(loadPuzzles);

  testWidgets('the picker starts under the bar, and the level list and the join screen keep their titles', (
    tester,
  ) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);

    // The picker has nothing to go back to, so it draws no title bar at all and
    // its body starts right under the phone's bar (m12 bug 1107f rule D).
    expect(find.byKey(const Key('hostTitleBar')), findsNothing);
    final picker = find.descendant(of: find.byType(party.GamesScreen), matching: find.byType(Scrollable)).first;
    expect(tester.getRect(picker).top, topBarHeightPx);
    expect(tester.getSize(picker).height, phoneScreenHeightPx - topBarHeightPx);

    // The level list, where "Shape Race" was almost cut off by the bar (bug
    // 1107f): its title and its back arrow are down here, in the clear.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);
    expectRoomBelowTheBar(tester, party.ShapeRaceScreen);
    final title = find.descendant(of: find.byType(party.ShapeRaceScreen), matching: find.text('Shape Race'));
    expect(tester.getRect(title).top, greaterThanOrEqualTo(topBarHeightPx), reason: 'the title is below the bar');
    // What the room costs the menus: the phone's screen, less the bar and the
    // title bar, is what the list has (m12 bug 1107f rule C's height cost).
    expect(tester.getSize(find.byType(Scrollable).first).height, phoneScreenHeightPx - topBarHeightPx - kToolbarHeight);

    // The join screen, whose title ran into the bar's labels too.
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await settle(tester);
    expectRoomBelowTheBar(tester, party.JoinScreen);

    await tester.runAsync(host.dispose);
  });

  testWidgets('the title bar back arrow is in the clear and pops to the picker, with the host still on', (
    tester,
  ) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);

    final back = find.descendant(
      of: find.byType(party.ShapeRaceScreen),
      matching: find.byKey(const Key('hostTitleBarBack')),
    );
    expect(back, findsOneWidget);
    expect(tester.getRect(back).top, greaterThanOrEqualTo(topBarHeightPx), reason: 'the arrow is not under the bar');
    await tester.tap(back);
    await settle(tester);
    expect(find.byType(party.ShapeRaceScreen), findsNothing);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(host.live, isTrue, reason: 'a back arrow goes up the games, it does not stop the host');

    await tester.runAsync(host.dispose);
  });

  testWidgets('"Show on this device" loses the picker\'s title bar too', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);
    // The bar is above the games here too, and the picker is still the route
    // with nothing to go back to (rule D).
    expect(find.byKey(const Key('hostTitleBar')), findsNothing);
    expect(
      tester.getRect(find.descendant(of: find.byType(party.GamesScreen), matching: find.byType(Scrollable)).first).top,
      topBarHeightPx,
    );
    await tester.runAsync(host.dispose);
  });

  testWidgets('the phone\'s menus leave 12 at the top of their bodies, where 24 would waste room', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final picker = tester.widget<ListView>(
      find.descendant(of: find.byType(party.GamesScreen), matching: find.byType(ListView)),
    );
    expect(picker.padding, const EdgeInsets.fromLTRB(24, 12, 24, 24));

    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);
    final levels = tester.widget<ListView>(
      find.descendant(of: find.byType(party.ShapeRaceScreen), matching: find.byType(ListView)),
    );
    expect(levels.padding, const EdgeInsets.fromLTRB(24, 12, 24, 24));

    await tester.runAsync(host.dispose);
  });

  testWidgets('the round keeps the whole screen: the board still fills it behind the bar', (tester) async {
    await pumpHostApp(tester);
    final host = await soloRound(tester);

    // Only the menus have a title bar; the round draws under the bar as it
    // did (m12 bug 1107f rule C), so its board keeps every pixel (m12 §5).
    expect(find.byKey(const Key('hostTitleBar')), findsNothing);
    expect(tester.getRect(find.byType(party.PuzzleScreen)), const Rect.fromLTWH(0, 0, 852, 393));
    expect(tester.getRect(find.byType(PuzzlePlayView)), const Rect.fromLTWH(0, 0, 852, 393));

    await tester.runAsync(host.dispose);
  });

  testWidgets('the hosted menus show no focus look, and a button lights only under a thumb', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final scheme = Theme.of(tester.element(find.byType(party.GamesScreen))).colorScheme;

    // Rule A on this phone: Shape Race's card has the focus, as the remote
    // expects, but no thumb put it there, so nothing is highlighted (bug
    // 1107f).
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.surfaceContainerHighest, ring: 0));

    // A thumb on the card lights it up.
    final card = tester.getCenter(find.byKey(const Key('pickShapeRace')));
    final finger = await tester.startGesture(card);
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.primaryContainer, ring: party.hostRingPx));

    // Lifting the thumb takes the look away and presses nothing.
    await finger.cancel();
    await tester.pump();
    expect(drawn(tester, 'pickShapeRace'), (fill: scheme.surfaceContainerHighest, ring: 0));
    expect(find.byType(party.ShapeRaceScreen), findsNothing);

    await tester.runAsync(host.dispose);
  });
}
