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

/// Whether the focus ring shows round the picker card under [key] this frame
/// (M13 3b), read off the card's own [party.HostCardFocus].
bool lit(WidgetTester tester, String key) => tester
    .widget<party.HostCardFocus>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(party.HostCardFocus)))
    .isLit;

/// The frame's scale for [screen]'s picture, or 1 outside a frame.
double frameScaleOf(WidgetTester tester, Type screen) =>
    party.HostFrameInfo.maybeOf(tester.element(find.byType(screen)))?.scale ?? 1.0;

/// Expects [finder]'s rect to be [expected] to within a rounding of the
/// frame's transform: a host screen's device rect is its frame rect times the
/// frame's scale, and the last bit can split (M16 phonehost2 wph).
void expectRect(WidgetTester tester, Finder finder, Rect expected) {
  final rect = tester.getRect(finder);
  expect(rect.left, closeTo(expected.left, 1e-6));
  expect(rect.top, closeTo(expected.top, 1e-6));
  expect(rect.right, closeTo(expected.right, 1e-6));
  expect(rect.bottom, closeTo(expected.bottom, 1e-6));
}

/// Checks that [screen]'s title bar starts below the phone's bar and meets none
/// of its parts (m12 bug 1107f rule C): its title ran into the bar's mode
/// labels, and its back arrow hid under the player's chip.
///
/// The screens here are still on the old `HostScreen`, which keeps the phone
/// bar's height above its title bar in frame px. Inside the host's frame (M16
/// phonehost2 wph) the frame itself already starts under the bar, so both are
/// added up: `topBarHeightPx` on the device plus `topBarHeightPx` of frame.
void expectRoomBelowTheBar(WidgetTester tester, Type screen) {
  final scale = frameScaleOf(tester, screen);
  final bar = tester.getRect(titleBarOf(screen));
  expect(bar.top, closeTo(topBarHeightPx * (1 + scale), 1e-6), reason: 'the title bar starts below the phone bar');
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

    // The picker is a frame screen (S8p), so it has the frame's 64 px header
    // at the frame's top, under the phone's bar (M16 phonehost2 wph). It has
    // nothing to go back to, so no back arrow (m12 bug 1107f rule D).
    final pickerBar = titleBarOf(party.GamesScreen);
    expect(pickerBar, findsOneWidget);
    expect(tester.getRect(pickerBar).top, closeTo(topBarHeightPx, 1e-6));
    expect(
      find.descendant(of: find.byType(party.GamesScreen), matching: find.byKey(const Key('hostTitleBarBack'))),
      findsNothing,
    );

    // The level list, where "Shape Race" was almost cut off by the bar (bug
    // 1107f): its title and its back arrow are down here, in the clear.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);
    expectRoomBelowTheBar(tester, party.ShapeRaceScreen);
    final title = find.descendant(of: find.byType(party.ShapeRaceScreen), matching: find.text('Shape Race'));
    expect(tester.getRect(title).top, greaterThanOrEqualTo(topBarHeightPx), reason: 'the title is below the bar');
    // What the room costs the menus, in the frame's px: the frame's height,
    // less the bar and the title bar the old screen keeps in it (m12 bug
    // 1107f rule C's height cost). A size inside the frame is frame px; only
    // its rect is drawn at the frame's scale.
    expect(tester.getSize(find.byType(Scrollable).first).height, 540 - topBarHeightPx - kToolbarHeight);

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

  testWidgets('"Show on this device" loses the picker\'s back arrow too', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);
    // The frame is under the bar here too, and the picker is still the route
    // with nothing to go back to (rule D): its header stays, its arrow does not.
    final pickerBar = titleBarOf(party.GamesScreen);
    expect(tester.getRect(pickerBar).top, closeTo(topBarHeightPx, 1e-6));
    expect(
      find.descendant(of: find.byType(party.GamesScreen), matching: find.byKey(const Key('hostTitleBarBack'))),
      findsNothing,
    );
    await tester.runAsync(host.dispose);
  });

  testWidgets('the menus still on the old screen leave 12 at the top of their bodies', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    // The picker is a frame screen now and uses none of the old menu's
    // padding (S8p); the rule stays for the lists still on HostScreen.
    expect(find.descendant(of: find.byType(party.GamesScreen), matching: find.byType(ListView)), findsNothing);

    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);
    final levels = tester.widget<ListView>(
      find.descendant(of: find.byType(party.ShapeRaceScreen), matching: find.byType(ListView)),
    );
    expect(levels.padding, const EdgeInsets.fromLTRB(24, 12, 24, 24));

    await tester.runAsync(host.dispose);
  });

  testWidgets('the round fills the frame below the bar', (tester) async {
    await pumpHostApp(tester);
    final host = await soloRound(tester);

    // Only the menus have a title bar; the round is the frame's whole picture
    // (M16 phonehost2 wph), which starts under the bar, so the board keeps
    // every pixel the host's frame has (m12 §5).
    expect(find.byKey(const Key('hostTitleBar')), findsNothing);
    expectRect(tester, find.byType(party.PuzzleScreen), const Rect.fromLTRB(0, topBarHeightPx, 852, 393));
    expectRect(tester, find.byType(PuzzlePlayView), const Rect.fromLTRB(0, topBarHeightPx, 852, 393));

    await tester.runAsync(host.dispose);
  });

  testWidgets('the hosted menus show no focus ring, and a thumb does not start one', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);

    // Rule A on this phone: Shape Race's card has the focus, as the remote
    // expects, but no thumb put it there, so no ring shows (bug 1107f).
    expect(lit(tester, 'pickShapeRace'), isFalse);

    // A thumb on the card starts no ring either, and lifting it presses
    // nothing.
    final card = tester.getCenter(find.byKey(const Key('pickShapeRace')));
    final finger = await tester.startGesture(card);
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(lit(tester, 'pickShapeRace'), isFalse);

    await finger.cancel();
    await tester.pump();
    expect(lit(tester, 'pickShapeRace'), isFalse);
    expect(find.byType(party.ShapeRaceScreen), findsNothing);

    await tester.runAsync(host.dispose);
  });
}
