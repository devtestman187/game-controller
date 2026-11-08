import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The tall bar the phone app draws over the host's screens (its
/// topBarHeightPx): the room a title bar must leave at the top on a phone, and
/// the body's top where a screen has no title bar.
const phoneBarPx = 52.0;

/// The harness's screen, a TV's and the Windows app's size.
const screenHeightPx = 540.0;

/// [screen]'s title bar, whichever route it is on.
Finder titleBarOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byKey(const Key('hostTitleBar')));

/// [screen]'s scrolling list.
Finder listOf(Type screen) => find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first;

/// The host's screens as the phone app mounts them: the picker is the first
/// route under the phone's bar, so there is nothing below it to go back to.
Future<void> pumpPhone(WidgetTester tester) =>
    pumpHost(tester, screen: const GamesScreen(), overrides: [hostBarHeightProvider.overrideWithValue(phoneBarPx)]);

void main() {
  test('a menu keeps 12 at the top where the phone bar is above, and 24 where it is not', () {
    expect(hostMenuPadding(phoneBarPx), const EdgeInsets.fromLTRB(24, 12, 24, 24));
    expect(hostMenuPadding(0), const EdgeInsets.all(24));
  });

  testWidgets('the picker on the phone has no title bar, so its body starts under the bar', (tester) async {
    await pumpPhone(tester);
    // Nothing to go back to: no title bar at all (m12 bug 1107f rule D).
    expect(find.byKey(const Key('hostTitleBar')), findsNothing);
    expect(tester.getRect(listOf(GamesScreen)).top, phoneBarPx);
    expect(tester.getSize(listOf(GamesScreen)).height, screenHeightPx - phoneBarPx);
  });

  testWidgets('a phone menu leaves 12 at the top, where its bar gives the room', (tester) async {
    await pumpPhone(tester);
    final list = tester.widget<ListView>(
      find.descendant(of: find.byType(GamesScreen), matching: find.byType(ListView)),
    );
    expect(list.padding, const EdgeInsets.fromLTRB(24, 12, 24, 24));
  });

  testWidgets('a TV menu keeps its 24 at the top', (tester) async {
    await pumpHost(tester, screen: const GamesScreen());
    final list = tester.widget<ListView>(
      find.descendant(of: find.byType(GamesScreen), matching: find.byType(ListView)),
    );
    expect(list.padding, const EdgeInsets.all(24));
  });

  testWidgets('every host screen with a title bar leaves the phone bar free, and its back arrow pops', (tester) async {
    await pumpPhone(tester);

    // The level list, whose title met the bar's mode labels (bug 1107f).
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(ShapeRaceScreen)).top, phoneBarPx);
    expect(
      tester.getRect(find.descendant(of: find.byType(ShapeRaceScreen), matching: find.text('Shape Race'))).top,
      greaterThanOrEqualTo(phoneBarPx),
      reason: 'the title is below the phone bar',
    );

    // Its back arrow is in the bar and goes back to the picker.
    final back = find.descendant(of: find.byType(ShapeRaceScreen), matching: find.byKey(const Key('hostTitleBarBack')));
    expect(back, findsOneWidget);
    expect(tester.getRect(back).top, greaterThanOrEqualTo(phoneBarPx));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byKey(const Key('hostTitleBar')), findsNothing, reason: 'the picker stays without one');

    // The join screen, whose title ran into the bar's labels too.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(JoinScreen)).top, phoneBarPx);
  });

  testWidgets('the settings screen leaves the phone bar free too', (tester) async {
    await pumpPhone(tester);
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(PuzzleSettingsScreen)).top, phoneBarPx);
    // Its own button is in the bar, below the phone's.
    expect(tester.getRect(find.byKey(const Key('resetPuzzleSettings'))).top, greaterThanOrEqualTo(phoneBarPx));
  });

  testWidgets('the stats screen draws its title bar at the top, as its TV screen always did', (tester) async {
    await pumpHost(tester, screen: const StatsScreen());
    expect(tester.getRect(titleBarOf(StatsScreen)).top, 0);
  });

  testWidgets('a TV host keeps the picker\'s title bar at the top, where its app bar was', (tester) async {
    // The bar is zero here, so a screen with nothing to go back to keeps its
    // title bar (rule D is about the phone's bar, which the TV has not got).
    await pumpHost(tester, screen: const GamesScreen());
    expect(tester.getRect(titleBarOf(GamesScreen)).top, 0);
    expect(find.text('Play'), findsOneWidget);

    // The TV app's own way in, from its home screen, keeps it too.
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(GamesScreen)).top, 0);
  });
}
