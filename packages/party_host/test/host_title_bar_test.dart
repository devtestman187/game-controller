import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The tall bar the phone app draws over the host's screens (its
/// topBarHeightPx): the room a title bar must leave at the top on a phone.
const phoneBarPx = 52.0;

/// [screen]'s title bar, whichever route it is on.
Finder titleBarOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byKey(const Key('hostTitleBar')));

void main() {
  testWidgets('every host screen with a title bar leaves the phone bar free, and its back arrow pops', (tester) async {
    await pumpHost(tester, screen: const StubHome(), overrides: [hostBarHeightProvider.overrideWithValue(phoneBarPx)]);

    // The game picker.
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(GamesScreen)).top, phoneBarPx);

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

    // The join screen, whose title ran into the bar's labels too.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(JoinScreen)).top, phoneBarPx);
  });

  testWidgets('the settings screen leaves the phone bar free too', (tester) async {
    await pumpHost(tester, screen: const StubHome(), overrides: [hostBarHeightProvider.overrideWithValue(phoneBarPx)]);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(PuzzleSettingsScreen)).top, phoneBarPx);
    // Its own button is in the bar, below the phone's.
    expect(tester.getRect(find.byKey(const Key('resetPuzzleSettings'))).top, greaterThanOrEqualTo(phoneBarPx));
  });

  testWidgets('the stats screen leaves the phone bar free too', (tester) async {
    await pumpHost(
      tester,
      screen: const StatsScreen(),
      overrides: [hostBarHeightProvider.overrideWithValue(phoneBarPx)],
    );
    expect(tester.getRect(titleBarOf(StatsScreen)).top, phoneBarPx);
  });

  testWidgets('a TV host draws its title bar at the top, where its app bar was', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(tester.getRect(titleBarOf(GamesScreen)).top, 0);
  });
}
